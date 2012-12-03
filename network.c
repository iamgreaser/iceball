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

client_t to_server;
client_t to_client_local;
client_t to_clients[CLIENT_MAX];
// TODO: binary search tree

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

char *net_fetch_file(const char *fname, int *flen)
{
	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
	{
		perror("net_fetch_file");
		return NULL;
	}
	
	int buf_len = 512;
	int buf_pos = 0;
	char *buf = malloc(buf_len+1);
	// TODO: check if NULL
	int buf_cpy;
	
	while(!feof(fp))
	{
		int fetch_len = buf_len-buf_pos;
		buf_cpy = fread(&buf[buf_pos], 1, fetch_len, fp);
		if(buf_cpy == -1)
		{
			fclose(fp);
			free(buf);
			return NULL;
		}
		
		buf_pos += buf_cpy;
		
		if(feof(fp))
			break;
		
		buf_len += (buf_len>>1)+1;
		buf = realloc(buf, buf_len+1);
	}
	
	fclose(fp);
	
	*flen = buf_pos;
	buf[buf_pos] = '\0';
	return buf;
}

void net_eat_c2s(client_t *cli)
{
	// TODO: sanity checks / handle fatal errors correctly
	packet_t *pkt, *npkt;
	for(pkt = cli->head; pkt != NULL; pkt = npkt)
	{
		npkt = pkt->n;
		
		switch(pkt->data[0])
		{
			case 0x30: {
				// 0x30 flags namelen name[namelen] 0x00
				// file transfer request
				char *fname = pkt->data + 3;
				int udtype = pkt->data[1] & 15;
				const char *ftype = net_aux_gettype_str(udtype);
				
				printf("file request: %02X %s \"%s\"\n",
					udtype, (ftype == NULL ? "*ERROR*" : ftype), fname);
				
				// check if we're allowed to fetch that
				if(!path_type_server_readable(path_get_type(fname)))
				{
					// error! ignoring for now.
					net_packet_free(pkt, &(cli->head), &(cli->tail));
					break;
				}
				
				// check if we have a file in the queue
				if(sfetch_udtype != UD_INVALID)
				{
					// error! ignoring for now.
					net_packet_free(pkt, &(cli->head), &(cli->tail));
					break;
				}
				
				// k let's give this a whirl
				// TODO: allow transferring of objects
				sfetch_ubuf = net_fetch_file(fname, &sfetch_ulen);
				
				if(sfetch_ubuf != NULL)
				{
					sfetch_udtype = udtype;
					
					// TODO: compression
					sfetch_cbuf = malloc(sfetch_ulen);
					memcpy(sfetch_cbuf, sfetch_ubuf, sfetch_ulen);
					sfetch_clen = sfetch_ulen;
					
					// assemble packet
					char buf[9];
					buf[0] = 0x31;
					*(uint32_t *)&buf[1] = sfetch_ulen;
					*(uint32_t *)&buf[5] = sfetch_clen;
					
					net_packet_push(9, buf, pkt->sockfd,
						&(cli->send_head), &(cli->send_tail));
				} else {
					// abort
					char buf[] = "\x35";
					net_packet_push(1, buf, pkt->sockfd,
						&(cli->send_head), &(cli->send_tail));
					
				}
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x34: {
				// 0x34:
				// abort incoming file transfer
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			default:
				if(pkt->data[0] >= 0x40 && ((uint8_t)pkt->data[0]) <= 0x7F)
					break;
				
				net_packet_free(pkt, &(cli->head), &(cli->tail));
				break;
		}
	}
}

void net_eat_s2c(client_t *cli)
{
	// TODO: sanity checks / handle fatal errors correctly
	packet_t *pkt, *npkt;
	for(pkt = cli->head; pkt != NULL; pkt = npkt)
	{
		npkt = pkt->n;
		
		switch(pkt->data[0])
		{
			case 0x31: {
				// 0x31 clen.u32 ulen.u32:
				// file transfer initiation
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x32: {
				// 0x32:
				// file transfer end
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x33: {
				// 0x33: offset.u32 len.u16 data[len]:
				// file transfer data
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x35: {
				// 0x35:
				// abort outgoing file transfer
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			default:
				if(pkt->data[0] >= 0x40 && ((uint8_t)pkt->data[0]) <= 0x7F)
					break;
				
				net_packet_free(pkt, &(cli->head), &(cli->tail));
				break;
		}
	}
}

void net_flush(void)
{
	// link-copy mode
	while(to_server.send_head != NULL)
	{
		packet_t *pfrom = to_server.send_head;
		
		// TODO: distinguish between local and network
		if(to_client_local.tail == NULL)
		{
			to_client_local.tail = to_client_local.head =
				net_packet_pop(&(to_server.send_head), &(to_server.send_tail));
		} else {
			packet_t *p2 = to_client_local.tail;
			to_client_local.tail = net_packet_pop(&(to_server.send_head), &(to_server.send_tail));
			p2->n = to_client_local.tail;
			to_client_local.tail->p = p2;
		};
	}
	
	while(to_client_local.send_head != NULL)
	{
		if(to_server.tail == NULL)
		{
			to_server.tail = to_server.head =
				net_packet_pop(&to_client_local.send_head, &to_client_local.send_tail);
		} else {
			packet_t *p = to_server.tail;
			to_server.tail = net_packet_pop(&to_client_local.send_head, &to_client_local.send_tail);
			p->n = to_server.tail;
			to_server.tail->p = p;
		};
	}
	
	
	net_eat_c2s(&to_server);
	net_eat_s2c(&to_client_local);
}

void net_deinit_client(client_t *cli)
{
	while(cli->head != NULL)
		net_packet_free(cli->head, &(cli->head), &(cli->tail));
	while(cli->send_head != NULL)
		net_packet_free(cli->send_head, &(cli->send_head), &(cli->send_tail));
}

int net_init(void)
{
	int i;
	
	for(i = 0; i < CLIENT_MAX; i++)
	{
		to_clients[i].sockfd = -1;
		to_clients[i].head = to_clients[i].tail = NULL;
		to_clients[i].send_head = to_clients[i].send_tail = NULL;
	}
	
	to_server.sockfd = -1;
	to_server.head = to_server.tail = NULL;
	to_server.send_head = to_server.send_tail = NULL;
	
	to_client_local.sockfd = SOCKFD_LOCAL_LINKCOPY;
	to_client_local.head = to_client_local.tail = NULL;
	to_client_local.send_head = to_client_local.send_tail = NULL;
	
	return 0;
}

void net_deinit(void)
{
	int i;
	
	net_deinit_client(&to_server);
	net_deinit_client(&to_client_local);
	
	for(i = 0; i < CLIENT_MAX; i++)
		net_deinit_client(&(to_clients[i]));
}
