/*
    This file is part of Iceball.

    Iceball is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Iceball is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Iceball.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

packet_t *pkt_server_send_head = NULL;
packet_t *pkt_server_send_tail = NULL;
packet_t *pkt_server_recv_head = NULL;
packet_t *pkt_server_recv_tail = NULL;
packet_t *pkt_client_send_head = NULL;
packet_t *pkt_client_send_tail = NULL;
packet_t *pkt_client_recv_head = NULL;
packet_t *pkt_client_recv_tail = NULL;

char *cfetch_cbuf = NULL;
char *cfetch_ubuf = NULL;
int cfetch_clen = 0;
int cfetch_ulen = 0;
int cfetch_cpos = 0;
int cfetch_udtype = UD_INVALID;

char *sfetch_cbuf = NULL;
char *sfetch_ubuf = NULL;
int sfetch_clen = 0;
int sfetch_ulen = 0;
int sfetch_cpos = 0;
int sfetch_udtype = UD_INVALID;

int net_packet_push(int len, const char *data, int sockfd, packet_t **head, packet_t **tail)
{
	if(len > PACKET_LEN_MAX)
	{
		fprintf(stderr, "net_packet_new: packet too large (%i > %i)\n"
			, len, PACKET_LEN_MAX);
		return 1;
	}
	
	if(len < 1)
	{
		fprintf(stderr, "net_packet_new: packet too small (%i < 1)\n"
			, len);
		return 1;
	}
	
	packet_t *pkt = malloc(sizeof(packet_t)+len);
	if(pkt == NULL)
	{
		error_perror("net_packet_new");
		return 1;
	}
	
	memcpy(pkt->data, data, len);
	pkt->len = len;
	pkt->sockfd = sockfd;
	if(*head == NULL)
	{
		pkt->p = pkt->n = NULL;
		*head = *tail = pkt;
	} else {
		(*tail)->n = pkt;
		pkt->p = (*tail);
		pkt->n = NULL;
		*tail = pkt;
	}
	
	return 0;
}

int net_packet_push_lua(int len, const char *data, int sockfd, packet_t **head, packet_t **tail)
{
	if(len > PACKET_LEN_MAX)
	{
		fprintf(stderr, "net_packet_new: packet too large (%i > %i)\n"
			, len, PACKET_LEN_MAX);
		return 1;
	}
	
	if(len < 1)
	{
		fprintf(stderr, "net_packet_new: packet too small (%i < 1)\n"
			, len);
		return 1;
	}
	
	int poffs = (len >= 64 ? 3 : 1);
	
	packet_t *pkt = malloc(sizeof(packet_t)+len+poffs);
	if(pkt == NULL)
	{
		error_perror("net_packet_new");
		return 1;
	}
	
	pkt->data[0] = (poffs == 1 ? len+0x3F : 0x7F);
	if(poffs != 1)
	{
		pkt->data[1] = len&255;
		pkt->data[2] = len>>8;
	}
	
	memcpy(poffs + pkt->data, data, len);
	pkt->len = len + poffs;
	pkt->sockfd = sockfd;
	if(*head == NULL)
	{
		pkt->p = pkt->n = NULL;
		*head = *tail = pkt;
	} else {
		(*tail)->n = pkt;
		pkt->p = (*tail);
		pkt->n = NULL;
		*tail = pkt;
	}
	
	return 0;
}

packet_t *net_packet_pop(packet_t **head, packet_t **tail)
{
	if(*head == NULL)
		return NULL;
	
	packet_t *pkt = *head;
	*head = pkt->n;
	if(*head == NULL)
		*tail = NULL;
	else
		(*head)->p = NULL;
	
	pkt->p = pkt->n = NULL;
	
	return pkt;
}

void net_packet_free(packet_t *pkt, packet_t **head, packet_t **tail)
{
	if(pkt->p != NULL)
		pkt->p->n = pkt->n;
	if(pkt->n != NULL)
		pkt->n->p = pkt->p;
	
	if(head != NULL && pkt == *head)
		*head = pkt->n;
	if(tail != NULL && pkt == *tail)
		*tail = pkt->p;
	
	free(pkt);
}

const char *net_aux_gettype_str(int ftype)
{
	switch(ftype)
	{
		case UD_LUA:
			return "lua";
		case UD_MAP:
			return "map";
		case UD_MAP_ICEMAP:
			return "icemap";
		case UD_MAP_VXL:
			return "vxl";
		case UD_PMF:
			return "pmf";
		case UD_IMG:
		case UD_IMG_TGA:
			return "tga";
		case UD_JSON:
			return "json";
	}
	
	return NULL;
}

void net_flush(void)
{
	// link-copy mode
	while(pkt_server_send_head != NULL)
	{
		if(pkt_client_recv_tail == NULL)
		{
			pkt_client_recv_tail = pkt_client_recv_head =
				net_packet_pop(&pkt_server_send_head, &pkt_server_send_tail);
		} else {
			packet_t *p = pkt_client_recv_tail;
			pkt_client_recv_tail = net_packet_pop(&pkt_server_send_head, &pkt_server_send_tail);
			p->n = pkt_client_recv_tail;
			pkt_client_recv_tail->p = p;
		};
	}
	
	while(pkt_client_send_head != NULL)
	{
		if(pkt_server_recv_tail == NULL)
		{
			pkt_server_recv_tail = pkt_server_recv_head =
				net_packet_pop(&pkt_client_send_head, &pkt_client_send_tail);
		} else {
			packet_t *p = pkt_server_recv_tail;
			pkt_server_recv_tail = net_packet_pop(&pkt_client_send_head, &pkt_client_send_tail);
			p->n = pkt_server_recv_tail;
			pkt_server_recv_tail->p = p;
		};
	}
	
	// map transfer checks
	// TODO: sanity checks / handle fatal errors correctly
	packet_t *pkt, *npkt;
	for(pkt = pkt_server_recv_head; pkt != NULL; pkt = npkt)
	{
		npkt = pkt->n;
		
		switch(pkt->data[0])
		{
			case 0x30: {
				// 0x30 flags namelen name[namelen] 0x00
				// file transfer request
				char *fname = pkt->data + 3;
				int udtype = pkt->data[1] & 15;
				char *ftype = net_aux_gettype_str(udtype);
				
				printf("file request: %02X %s \"%s\"\n",
					udtype, (ftype == NULL ? "*ERROR*" : ftype), fname);
				
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_server_recv_tail);
			} break;
			case 0x34: {
				// 0x34:
				// abort incoming file transfer
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_server_recv_tail);
			} break;
			default:
				if(pkt->data[0] >= 0x40 && ((uint8_t)pkt->data[0]) <= 0x7F)
					break;
				
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_server_recv_tail);
				break;
		}
	}
	
	for(pkt = pkt_client_recv_head; pkt != NULL; pkt = npkt)
	{
		npkt = pkt->n;
		
		switch(pkt->data[0])
		{
			case 0x31: {
				// 0x31 flags clen.u32 ulen.u32 0x00:
				// file transfer initiation
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_client_recv_tail);
			} break;
			case 0x32: {
				// 0x32:
				// file transfer end
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_client_recv_tail);
			} break;
			case 0x33: {
				// 0x33: offset.u32 len.u16 data[len]:
				// file transfer data
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_client_recv_tail);
			} break;
			case 0x35: {
				// 0x35:
				// abort outgoing file transfer
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_client_recv_tail);
			} break;
			default:
				if(pkt->data[0] >= 0x40 && ((uint8_t)pkt->data[0]) <= 0x7F)
					break;
				
				net_packet_free(pkt, &pkt_server_recv_head, &pkt_client_recv_tail);
				break;
		}
	}
}

int net_init(void)
{
	// TODO!
	return 0;
}

void net_deinit(void)
{
	while(pkt_server_send_head != NULL)
		net_packet_free(net_packet_pop(&pkt_server_send_head, &pkt_server_send_tail), NULL, NULL);
	while(pkt_server_recv_head != NULL)
		net_packet_free(net_packet_pop(&pkt_server_recv_head, &pkt_server_recv_tail), NULL, NULL);
	while(pkt_client_send_head != NULL)
		net_packet_free(net_packet_pop(&pkt_client_send_head, &pkt_client_send_tail), NULL, NULL);
	while(pkt_client_recv_head != NULL)
		net_packet_free(net_packet_pop(&pkt_client_recv_head, &pkt_client_recv_tail), NULL, NULL);
}
