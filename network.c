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

int net_packet_push(int len, uint8_t *data, packet_t **head, packet_t **tail)
{
	if(len > PACKET_LEN_MAX)
	{
		fprintf(stderr, "net_packet_new: packet too large (%i > %i)\n"
			, len, PACKET_LEN_MAX);
		return 1;
	}
	
	packet_t *pkt = malloc(sizeof(packet_t));
	if(pkt == NULL)
	{
		error_perror("net_packet_new");
		return 1;
	}
	
	memcpy(pkt->data, data, len);
	pkt->len = len;
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

void net_packet_free(packet_t *pkt)
{
	if(pkt->p != NULL)
		pkt->p->n = pkt->n;
	if(pkt->n != NULL)
		pkt->n->p = pkt->p;
	
	free(pkt);
}

int net_init(void)
{
	// TODO!
	return 0;
}

void net_deinit(void)
{
	while(pkt_server_send_head != NULL)
		net_packet_free(net_packet_pop(&pkt_server_send_head, &pkt_server_send_tail));
	while(pkt_server_recv_head != NULL)
		net_packet_free(net_packet_pop(&pkt_server_recv_head, &pkt_server_recv_tail));
	while(pkt_client_send_head != NULL)
		net_packet_free(net_packet_pop(&pkt_client_send_head, &pkt_client_send_tail));
	while(pkt_client_recv_head != NULL)
		net_packet_free(net_packet_pop(&pkt_client_recv_head, &pkt_client_recv_tail));
}
