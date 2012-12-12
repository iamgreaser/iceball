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

#ifdef WIN32
WSADATA windows_sucks;
#endif

int server_sockfd_ipv4 = -1;
int server_sockfd_ipv6 = -1;

client_t to_server;
client_t to_client_local;
client_t to_clients[CLIENT_MAX];
// TODO: binary search tree

// SNIP: http://www.eyrie.org/~eagle/software/rra-c-util/
/*
 * Replacement for a missing inet_ntop.
 *
 * Provides an implementation of inet_ntop that only supports IPv4 addresses
 * for hosts that are missing it.  If you want IPv6 support, you need to have
 * a real inet_ntop function; this function is only provided so that code can
 * call inet_ntop unconditionally without needing to worry about whether the
 * host supports IPv6.
 *
 * The canonical version of this file is maintained in the rra-c-util package,
 * which can be found at <http://www.eyrie.org/~eagle/software/rra-c-util/>.
 *
 * Written by Russ Allbery <rra@stanford.edu>
 *
 * The authors hereby relinquish any claim to any copyright that they may have
 * in this work, whether granted under contract or by operation of law or
 * international treaty, and hereby commit to the public, at large, that they
 * shall not, at any time in the future, seek to enforce any copyright in this
 * work against any person or entity, or prevent any person or entity from
 * copying, publishing, distributing or creating derivative works of this
 * work.
 */

// Modified by GreaseMonkey, to support IPv6 and also to glue in nicely.
// This is also to be treated as public domain.
// ANYHOW, let's go.

// This may already be defined by the system headers.
#ifndef INET_ADDRSTRLEN
# define INET_ADDRSTRLEN 16
#endif

// Systems old enough to not support inet_ntop may not have this either.
#ifndef EAFNOSUPPORT
# define EAFNOSUPPORT EDOM
#endif

#if WIN32
const char *inet_ntop(int af, const void *src, char *dst, socklen_t cnt)
{
	const uint8_t *p;
	
	if (af == AF_INET)
	{
		if (cnt < INET_ADDRSTRLEN)
			return NULL;
		
		p = src;
		snprintf(dst, cnt, "%u.%u.%u.%u",
			(unsigned int) (p[0] & 0xff), (unsigned int) (p[1] & 0xff),
			(unsigned int) (p[2] & 0xff), (unsigned int) (p[3] & 0xff));
	} else if (af == AF_INET6) {
		if (cnt < 5*8)
			return NULL;
		
		p = src;
		snprintf(dst, cnt, "%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x",
			(unsigned int) (p[0] & 0xff), (unsigned int) (p[1] & 0xff),
			(unsigned int) (p[2] & 0xff), (unsigned int) (p[3] & 0xff),
			(unsigned int) (p[4] & 0xff), (unsigned int) (p[5] & 0xff),
			(unsigned int) (p[6] & 0xff), (unsigned int) (p[7] & 0xff),
			(unsigned int) (p[8] & 0xff), (unsigned int) (p[9] & 0xff),
			(unsigned int) (p[10] & 0xff), (unsigned int) (p[11] & 0xff),
			(unsigned int) (p[12] & 0xff), (unsigned int) (p[13] & 0xff),
			(unsigned int) (p[14] & 0xff), (unsigned int) (p[15] & 0xff));
	} else {
		return NULL;
	}
	return dst;
}
#endif
// END SNIP

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
	if(len+4 > PACKET_LEN_MAX)
	{
		fprintf(stderr, "net_packet_new: packet too large (%i > %i)\n"
			, len, PACKET_LEN_MAX-4);
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

void net_deinit_client(client_t *cli)
{
	while(cli->head != NULL)
		net_packet_free(cli->head, &(cli->head), &(cli->tail));
	while(cli->send_head != NULL)
		net_packet_free(cli->send_head, &(cli->send_head), &(cli->send_tail));
	
	cli->sockfd = -1;
}

void net_kick_sockfd_immediate(int sockfd, char *msg)
{
	char buf[260];
	buf[0] = 0x17;
	buf[1] = strlen(msg);
	memcpy(buf+2, msg, (int)(uint8_t)buf[1]);
	buf[2+(int)(uint8_t)buf[1]] = 0x00;
	
	fprintf(stderr, "KICK: %i \"%s\"\n", sockfd, msg);
	// only send what's necessary
	send(sockfd, buf, ((int)(uint8_t)buf[1])+1, 0);
	
	// call hook_disconnect
	{
		lua_getglobal(lstate_server, "server");
		lua_getfield(lstate_server, -1, "hook_disconnect");
		lua_remove(lstate_server, -2);
		if(!lua_isnil(lstate_server, -1))
		{
			if(sockfd >= 0)
				lua_pushinteger(lstate_server, sockfd);
			else
				lua_pushboolean(lstate_server, 1);
			
			lua_pushboolean(lstate_server, 1);
			lua_pushstring(lstate_server, msg);
			
			if(lua_pcall(lstate_server, 3, 0, 0) != 0)
			{
				printf("ERROR running server Lua (hook_disconnect): %s\n", lua_tostring(lstate_server, -1));
				lua_pop(lstate_server, 1);
				return;
			}
		} else {
			lua_pop(lstate_server, 1);
		}
	}
	
	// nuke it
	close(sockfd);
}

void net_kick_client_immediate(client_t *cli, char *msg)
{
	if(cli == &to_client_local)
	{
		fprintf(stderr, "KICK: local \"%s\"\n", msg);
		fprintf(stderr, "PANIC: I don't know how to handle a local client kick yet!\n");
		fflush(stderr);
		abort();
	}
	
	if(cli == NULL)
		return;
	
	net_kick_sockfd_immediate(cli->sockfd, msg);
	cli->sockfd = -1;
	net_deinit_client(cli);
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
	int i;
	
	// TODO: sanity checks / handle fatal errors correctly
	packet_t *pkt, *npkt;
	for(pkt = cli->head; pkt != NULL; pkt = npkt)
	{
		npkt = pkt->n;
		
		// TODO: actually discern the source
		client_t *other = &to_client_local;
		
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
					fprintf(stderr, "S->C transfer error: access denied\n");
					net_packet_free(pkt, &(cli->head), &(cli->tail));
					break;
				}
				
				// check if we have a file in the queue
				if(other->sfetch_udtype != UD_INVALID)
				{
					// error! ignoring for now.
					fprintf(stderr, "S->C transfer error: still sending file\n");
					net_packet_free(pkt, &(cli->head), &(cli->tail));
					break;
				}
				
				// k let's give this a whirl
				// TODO: allow transferring of objects
				other->sfetch_ubuf = net_fetch_file(fname, &(other->sfetch_ulen));
				
				if(other->sfetch_ubuf != NULL)
				{
					other->sfetch_udtype = udtype;
					
					uLongf cbound = compressBound(other->sfetch_ulen);
					other->sfetch_cbuf = malloc(cbound);
					// TODO: check if NULL
					if(compress((Bytef *)(other->sfetch_cbuf), &cbound,
						(Bytef *)(other->sfetch_ubuf), other->sfetch_ulen))
					{
						// abort
						fprintf(stderr, "S->C transfer error: could not compress!\n");
						
						if(other->sfetch_cbuf != NULL)
							free(other->sfetch_cbuf);
						free(other->sfetch_ubuf);
						other->sfetch_cbuf = NULL;
						other->sfetch_ubuf = NULL;
						
						char buf[] = "\x35";
						net_packet_push(1, buf, pkt->sockfd,
							&(cli->send_head), &(cli->send_tail));
						net_packet_free(pkt, &(cli->head), &(cli->tail));
						break;
					}
					other->sfetch_clen = (int)cbound;
					free(other->sfetch_ubuf);
					other->sfetch_ubuf = NULL;
					
					// assemble packets...
					
					// initial packet
					{
						char buf[9];
						buf[0] = 0x31;
						*(uint32_t *)&buf[1] = other->sfetch_clen;
						*(uint32_t *)&buf[5] = other->sfetch_ulen;
						
						net_packet_push(9, buf, pkt->sockfd,
							&(cli->send_head), &(cli->send_tail));
					}
					
					// data packets
					{
						char buf[1+4+2+1024];
						buf[0] = 0x33;
						for(i = 0; i < other->sfetch_clen; i += 1024)
						{
							int plen = other->sfetch_clen - i;
							if(plen > 1024)
								plen = 1024;
							*(uint32_t *)&buf[1] = (uint32_t)i;
							*(uint16_t *)&buf[5] = (uint16_t)plen;
							
							memcpy(&buf[7], &(other->sfetch_cbuf[i]), plen);
							
							net_packet_push(plen+7, buf, pkt->sockfd,
								&(cli->send_head), &(cli->send_tail));
						}
					}
					
					// success packet
					{
						char buf[1];
						buf[0] = 0x32;
						
						net_packet_push(1, buf, pkt->sockfd,
							&(cli->send_head), &(cli->send_tail));
					}
					
					// all good!
					free(other->sfetch_cbuf);
					other->sfetch_cbuf = NULL;
					other->sfetch_udtype = UD_INVALID;
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
				// TODO: actually abort
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
	client_t *other = &to_server;
	for(pkt = cli->head; pkt != NULL; pkt = npkt)
	{
		npkt = pkt->n;
		
		switch(pkt->data[0])
		{
			case 0x0F: {
				if(pkt->data[pkt->len-1] != '\x00')
				{
					fprintf(stderr, "ERROR: string not zero-terminated!\n");
				} else if(mod_basedir == NULL) {
					mod_basedir = strdup(2+pkt->data);
					boot_mode |= 8;
					printf("base dir = \"%s\"\n", mod_basedir);
				} else {
					fprintf(stderr, "ERROR: base dir already defined!\n");
					// TODO: make this fatal
				}
				
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x31: {
				// 0x31 clen.u32 ulen.u32:
				// file transfer initiation
				int clen = (int)*(uint32_t *)&(pkt->data[1]);
				int ulen = (int)*(uint32_t *)&(pkt->data[5]);
				//printf("clen=%i ulen=%i\n", clen, ulen);
				cli->cfetch_clen = clen;
				cli->cfetch_ulen = ulen;
				cli->cfetch_cbuf = malloc(clen);
				cli->cfetch_ubuf = NULL;
				cli->cfetch_cpos = 0;
				// TODO: check if NULL
				
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x32: {
				// 0x32:
				// file transfer end
				//printf("transfer END\n");
				cli->cfetch_ubuf = malloc(cli->cfetch_ulen);
				// TODO: check if NULL
				
				uLongf dlen = cli->cfetch_ulen;
				if(uncompress((Bytef *)(cli->cfetch_ubuf), &dlen,
					(Bytef *)(cli->cfetch_cbuf), cli->cfetch_clen) != Z_OK)
				{
					fprintf(stderr, "FETCH ERROR: could not decompress!\n");
					// TODO: make this fatal
					
					free(cli->cfetch_cbuf);
					free(cli->cfetch_ubuf);
					cli->cfetch_cbuf = NULL;
					cli->cfetch_ubuf = NULL;
					net_packet_free(pkt, &(cli->head), &(cli->tail));
					break;
				}
				
				free(cli->cfetch_cbuf);
				cli->cfetch_cbuf = NULL;
				
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x33: {
				// 0x33: offset.u32 len.u16 data[len]:
				// file transfer data
				int offs = (int)*(uint32_t *)&(pkt->data[1]);
				int plen = (int)*(uint16_t *)&(pkt->data[5]);
				//printf("pdata %08X: %i bytes\n", offs, plen);
				if(plen <= 0 || plen > 1024)
				{
					fprintf(stderr, "FETCH ERROR: length too long/short!\n");
				} else if(offs < 0 || offs+plen > cli->cfetch_clen) {
					fprintf(stderr, "FETCH ERROR: buffer overrun!\n");
					// TODO: make this fatal
				} else {
					memcpy(offs + cli->cfetch_cbuf, &(pkt->data[7]), plen);
					cli->cfetch_cpos = offs + plen;
				}
				
				net_packet_free(pkt, &(cli->head), &(cli->tail));
			} break;
			case 0x35: {
				// 0x35:
				// abort outgoing file transfer
				//printf("abort transfer\n");
				// TODO: actually abort
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

int net_flush_parse_onepkt(const char *data, int len)
{
	if(len <= 0)
		return 0;
	
	int cmd = data[0];
	int ilen = 0;
	
	if(cmd >= 0x40 && cmd <= 0x7E)
	{
		ilen = cmd-0x3E;
	} else if(cmd == 0x7F) {
		if(len < 4)
			return 0;
		
		ilen = (int)*(uint16_t *)&data[1];
		ilen += 3;
	} else switch(cmd) {
		case 0x0F: // baselen base[baselen] 0x00:
		case 0x17: // msglen msg[msglen] 0x00:
		{
			if(len < 2)
				return 0;
			
			ilen = (int)(uint8_t)data[1];
			ilen += 3;
		} break;
		case 0x30: // flags namelen name[namelen] 0x00:
		{
			if(len < 4)
				return 0;
			
			ilen = (int)(uint8_t)data[2];
			ilen += 4;
		} break;
		case 0x31: // clen.u32 ulen.u32:
			ilen = 9;
			break;
		case 0x33: // offset.u32 len.u16 data[len]
		{
			if(len < 7)
				return 0;
			
			ilen = (int)*(uint16_t *)&data[5];
			ilen += 7;
		} break;
		case 0x32:
		case 0x34:
		case 0x35:
			ilen = 1;
			break;
		default:
			// TODO: terminate cleanly instead of locking
			return 0;
	}
	
	//printf("cmd=%02X ilen=%i blen=%i\n", cmd, ilen, len);
	
	if(ilen > PACKET_LEN_MAX)
	{
		// TODO: terminate cleanly instead of locking
		return 0;
	}
	
	return (ilen <= len ? ilen : 0);
}

void net_flush_parse_c2s(client_t *cli)
{
	// TODO!
	int offs = 0;
	int len;
	char *data;
	
	len = cli->spkt_len;
	data = cli->spkt_buf;
	
	while(offs < len)
	{
		int nlen = net_flush_parse_onepkt(data+offs, len-offs);
		
		//printf("nlen=%i\n",nlen);
		if(nlen <= 0)
			break;
		
		net_packet_push(nlen, data+offs,
			cli->sockfd, &(to_server.head), &(to_server.tail));
		
		offs += nlen;
	}
	
	if(offs != 0)
	{
		//printf("offs=%i len=%i\n", offs, len);
		if(offs < len)
			memmove(data, data+offs, len-offs);
		
		cli->spkt_len -= offs;
	}
}

void net_flush_parse_s2c(client_t *cli)
{
	int offs = 0;
	int len;
	char *data;
	
	len = cli->rpkt_len;
	data = cli->rpkt_buf;
	
	while(offs < len)
	{
		int nlen = net_flush_parse_onepkt(data+offs, len-offs);
		
		if(nlen <= 0)
			break;
		
		//printf("nlen=%i\n",nlen);
		
		net_packet_push(nlen, data+offs,
			cli->sockfd, &(cli->head), &(cli->tail));
		
		offs += nlen;
	}
	
	if(offs != 0)
	{
		//printf("offs=%i len=%i\n", offs, len);
		if(offs < len)
		{
			//printf("LET THE MOVE\n");
			memmove(data, data+offs, len-offs);
		}
		cli->rpkt_len -= offs;
		//printf("new len: %i\n", cli->rpkt_len);
	}
}

client_t *net_find_sockfd(int sockfd)
{
	int i;
	client_t *cli;
	
	if(sockfd == SOCKFD_LOCAL)
	{
		return &to_client_local;
	} else if(sockfd >= 0) {
		for(i = 0; i < CLIENT_MAX; i++)
			if(to_clients[i].sockfd == sockfd)
				return &to_clients[i];
	} else {
		return NULL;
	}
	
	return NULL;
}

client_t *net_alloc_sockfd(int sockfd)
{
	int i;
	client_t *cli = net_find_sockfd(sockfd);
	
	if(cli != NULL)
		return cli;
	
	for(i = 0; i < CLIENT_MAX; i++)
	{
		if(to_clients[i].sockfd == -1)
		{
			to_clients[i].sockfd = sockfd;
			return &to_clients[i];
		}
	}
	
	return NULL;
}

int net_flush_transfer(client_t *cfrom, client_t *cto, packet_t *pfrom)
{
	if(cto->isfull)
	{
		//printf("still full!\n");
		return 1;
	}
	
	int len = (cto == &to_server ? cfrom->spkt_len : cto->rpkt_len);
	
	if(pfrom->len + len > PACKET_LEN_MAX*2)
	{
		// TODO: send this somehow
		//printf("FULL!\n");
		cto->isfull = 1;
		return 1;
	} else {
		if(pfrom->p != NULL)
			pfrom->p->n = pfrom->n;
		else
			cfrom->send_head = pfrom->n;
		
		if(pfrom->n != NULL)
			pfrom->n->p = pfrom->p;
		else
			cfrom->send_tail = pfrom->p;
		
		// here's the linkcopy version
		/*
		pfrom->n = NULL;
		pfrom->p = NULL;
		
		if(cto->tail == NULL)
		{
			cto->tail = cto->head = pfrom;
		} else {
			packet_t *p2 = cto->tail;
			cto->tail = pfrom;
			p2->n = pfrom;
			pfrom->p = p2;
		};
		
		return 0;
		*/
		
		// and of course the serialised version:
		if(cto == &to_server)
		{
			memcpy(cfrom->spkt_buf + cfrom->spkt_len, pfrom->data, pfrom->len);
			cfrom->spkt_len += pfrom->len;
		} else {
			memcpy(cto->rpkt_buf + cto->rpkt_len, pfrom->data, pfrom->len);
			cto->rpkt_len += pfrom->len;
		}
	}
	return 0;
}

void net_flush_accept_one(int sockfd, struct sockaddr_storage *ss, socklen_t slen)
{
	char xstr[128];
	xstr[0] = '?';
	xstr[1] = '\0';
	int cport = 0;
	switch(ss->ss_family)
	{
		case AF_INET:
			inet_ntop(AF_INET, &(((struct sockaddr_in *)(ss))->sin_addr)
				, xstr, 127);
			cport = ((struct sockaddr_in *)(ss))->sin_port;
			break;
		case AF_INET6:
			inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)(ss))->sin6_addr)
				, xstr, 127);
			cport = ((struct sockaddr_in6 *)(ss))->sin6_port;
			break;
	}
	
	printf("connection from %s, port %i, family %i\n", xstr, cport, ss->ss_family);
	
	// disable Nagle's algo
	int yes = 1;
	if(setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, (void *)&yes, sizeof(yes)) == -1)
	{
		net_kick_sockfd_immediate(sockfd, "Could not disable Nagle's algorithm!"
			" Kicked because gameplay will be complete shit otherwise.");
		return;
	}
	
	// set connection nonblocking
	yes = 1;
#ifdef WIN32
	if(ioctlsocket(sockfd,FIONBIO,(void *)&yes) == -1) {
#else
	if(fcntl(sockfd, F_SETFL,
			fcntl(sockfd, F_GETFL) | O_NONBLOCK) == -1) {
#endif
		net_kick_sockfd_immediate(sockfd, "Could not set up a nonblocking connection!");
		return;
	}
	
	// get a slot
	client_t *cli = net_alloc_sockfd(sockfd);
	
	if(cli == NULL)
	{
		net_kick_sockfd_immediate(sockfd, "Server ran out of free slots!");
		return;
	}
	
	// call hook_connect
	lua_getglobal(lstate_server, "server");
	lua_getfield(lstate_server, -1, "hook_connect");
	lua_remove(lstate_server, -2);
	if(!lua_isnil(lstate_server, -1))
	{
		lua_pushinteger(lstate_server, sockfd);
		lua_newtable(lstate_server);
		
		switch(ss->ss_family)
		{
			case AF_INET:
			case AF_INET6:
				if(ss->ss_family == AF_INET6)
					lua_pushstring(lstate_server, "tcp/ip6");
				else
					lua_pushstring(lstate_server, "tcp/ip");
				
				lua_setfield(lstate_server, -2, "proto");
				
				lua_newtable(lstate_server);
				lua_pushstring(lstate_server, xstr);
				lua_setfield(lstate_server, -2, "ip");
				lua_pushnil(lstate_server); // not supported yet!
				lua_setfield(lstate_server, -2, "host");
				lua_pushinteger(lstate_server, cport);
				lua_setfield(lstate_server, -2, "cport");
				lua_pushinteger(lstate_server, net_port);
				lua_setfield(lstate_server, -2, "sport");
				
				lua_setfield(lstate_server, -2, "addr");
				break;
		}
		
		if(lua_pcall(lstate_server, 2, 0, 0) != 0)
		{
			printf("ERROR running server Lua (hook_connect): %s\n", lua_tostring(lstate_server, -1));
			lua_pop(lstate_server, 2);
			net_kick_sockfd_immediate(sockfd, "hook_connect failed on server");
			return;
		}
	} else {
		lua_pop(lstate_server, 1);
	}
	
	// send pkg basedir packet
	{
		char buf[260];
		buf[0] = 0x0F;
		buf[1] = strlen(mod_basedir);
		memcpy(buf+2, mod_basedir, (int)(uint8_t)buf[1]);
		buf[2+(int)(uint8_t)buf[1]] = 0x00;
		
		net_packet_push(2+((int)(uint8_t)buf[1])+1, buf, sockfd,
			&(to_server.send_head), &(to_server.send_tail));
	}
}

void net_flush_accept(void)
{
	if(server_sockfd_ipv6 != -1)
	{
		struct sockaddr_storage ss;
		socklen_t slen = sizeof(ss);
		int sockfd = accept(server_sockfd_ipv6, (struct sockaddr *)&ss, &slen);
		
		if(sockfd == -1)
		{
#ifdef WIN32
			int err = WSAGetLastError();
			if(err != WSAEWOULDBLOCK)
#else
			int err = errno;
			if(err != EAGAIN && err != EWOULDBLOCK)
#endif
			{
				perror("net_flush_accept(accept.6)");
			}
		} else {
			net_flush_accept_one(sockfd, &ss, slen);
		}
	}
	
	if(server_sockfd_ipv4 != -1)
	{
		struct sockaddr_storage ss;
		socklen_t slen = sizeof(ss);
		int sockfd = accept(server_sockfd_ipv4, (struct sockaddr *)&ss, &slen);
		
		if(sockfd == -1)
		{
#ifdef WIN32
			int err = WSAGetLastError();
			if(err != WSAEWOULDBLOCK)
#else
			int err = errno;
			if(err != EAGAIN && err != EWOULDBLOCK)
#endif
			{
				perror("net_flush_accept(accept.4)");
			}
		} else {
			net_flush_accept_one(sockfd, &ss, slen);
		}
	}
}

void net_flush_snr(client_t *cli)
{
	if(cli == &to_client_local)
	{
		if(boot_mode & 2)
		{
			// don't do anything, it's already in the buffer
			return;
		} else {
			{
			int bs = send(cli->sockfd, cli->spkt_buf,
				cli->spkt_len, 0);
				
				if(bs == -1)
				{
#ifdef WIN32
					int err = WSAGetLastError();
					if(err != WSAEWOULDBLOCK)
#else
					int err = errno;
					if(err != EAGAIN && err != EWOULDBLOCK)
#endif
					{
						perror("net_flush_snr(client.send)");
						net_kick_client_immediate(cli, "Error sending packet!");
						return;
					}
				} else if(bs > 0) {
					//printf("sent data! %i\n", bs);
					cli->spkt_len -= bs;
					memmove(cli->spkt_buf, cli->spkt_buf+bs, cli->spkt_len);
				}
			}
			
			{
				int bs = recv(cli->sockfd, cli->rpkt_buf+cli->rpkt_len,
					PACKET_LEN_MAX*2-cli->rpkt_len, 0);
				
				if(bs == -1)
				{
#ifdef WIN32
					int err = WSAGetLastError();
					if(err != WSAEWOULDBLOCK)
#else
					int err = errno;
					if(err != EAGAIN && err != EWOULDBLOCK)
#endif
					{
						perror("net_flush_snr(client.recv)");
						net_kick_client_immediate(cli, "Error receiving packet!");
						return;
					}
				} else if(bs == 0) {
					fprintf(stderr, "%i: recv: connection axed\n", cli->sockfd);
					net_kick_client_immediate(cli, "Connection axed.");
					return;
				} else {
					//printf("got data! %i\n", bs);
					cli->rpkt_len += bs;
				}
			}
		}
	} else {
		//printf("send sockfd %i %i %i\n", cli->sockfd, cli->rpkt_len, cli->rpkt_len);
		{
			int bs = send(cli->sockfd, cli->rpkt_buf,
				cli->rpkt_len, 0);
			
			if(bs == -1)
			{
#ifdef WIN32
				int err = WSAGetLastError();
				if(err != WSAEWOULDBLOCK)
#else
				int err = errno;
				if(err != EAGAIN && err != EWOULDBLOCK)
#endif
				{
					perror("net_flush_snr(server.send)");
					net_kick_client_immediate(cli, "Error sending packet!");
					return;
				}
			} else if(bs > 0) {
				//printf("server sent data! %i\n", bs);
				cli->rpkt_len -= bs;
				memmove(cli->rpkt_buf, cli->rpkt_buf+bs, cli->rpkt_len);
			}
		}
		
		{
			int bs = recv(cli->sockfd, cli->spkt_buf+cli->spkt_len,
				PACKET_LEN_MAX*2-cli->spkt_len, 0);
			
			if(bs == -1)
			{
#ifdef WIN32
				int err = WSAGetLastError();
				if(err != WSAEWOULDBLOCK)
#else
				int err = errno;
				if(err != EAGAIN && err != EWOULDBLOCK)
#endif
				{
					perror("net_flush_snr(server.recv)");
					net_kick_client_immediate(cli, "Error receiving packet!");
					return;
				}
			} else if(bs == 0) {
				fprintf(stderr, "%i: recv: connection axed\n", cli->sockfd);
				net_kick_client_immediate(cli, "Connection axed.");
				return;
			} else {
				//printf("server got data! %i\n", bs);
				cli->spkt_len += bs;
			}
		}
	}
}

void net_flush(void)
{
	packet_t *pkt, *npkt;
	int i;
	
	if(boot_mode & 2)
	{
		net_flush_accept();
		
		// clear full flags
		for(i = 0; i < CLIENT_MAX; i++)
			to_clients[i].isfull = 0;
		to_client_local.isfull = 0;
		to_server.isfull = 0;
		
		// serialise the packets
		for(pkt = to_server.send_head; pkt != NULL; pkt = npkt)
		{
			npkt = pkt->n;
			
			//printf("pkt = %016llX\n", pkt);
			
			client_t *cli = net_find_sockfd(pkt->sockfd);
			
			if(cli == NULL)
			{
				fprintf(stderr, "EDOOFUS: given sockfd %i could not be found!\n"
					, pkt->sockfd);
				net_packet_free(pkt, &(to_server.send_head), &(to_server.send_tail));
				//fflush(stderr);
				//abort();
			} else {
				net_flush_transfer(&to_server, cli, pkt);
			}
		}
		
		for(i = 0; i < CLIENT_MAX; i++)
			if(to_clients[i].sockfd != -1)
				net_flush_snr(&to_clients[i]);
		
		// parse the incoming stuff
		for(i = 0; i < CLIENT_MAX; i++)
			if(to_clients[i].sockfd != -1)
				net_flush_parse_c2s(&to_clients[i]);
		
		net_flush_parse_c2s(&to_client_local);
	}
	
	if(boot_mode & 1)
	{
		to_server.isfull = 0;
		
		for(pkt = to_client_local.send_head; pkt != NULL; pkt = npkt)
		{
			npkt = pkt->n;
			
			net_flush_transfer(&to_client_local, &to_server, pkt);
		}
		
		net_flush_snr(&to_client_local);
		
		net_flush_parse_s2c(&to_client_local);
	}
	
	if(boot_mode & 2)
		net_eat_c2s(&to_server);
	if(boot_mode & 1)
		net_eat_s2c(&to_client_local);
}

int net_gethost(char *name, int port, struct sockaddr *sa, size_t alen)
{
	char port_str[32];
	struct addrinfo ainf;
	
	memset(&ainf, 0, sizeof(ainf));
	ainf.ai_flags = 0;
	ainf.ai_family = AF_UNSPEC;
	ainf.ai_socktype = SOCK_STREAM;
	ainf.ai_protocol = 0;
	
	snprintf(port_str, 31, "%i", net_port);
	
	struct addrinfo *res;
	int err = getaddrinfo(name, port_str, &ainf, &res);
	if(err != 0)
	{
		fprintf(stderr, "net_gethost: %s\n", gai_strerror(err));
		return 1;
	}
	
	struct addrinfo *best,*fol;
	best = NULL;
	for(fol = res; fol != NULL; fol = fol->ai_next)
	{
		char xstr[128];
		xstr[0] = '?';
		xstr[1] = '\0';
		switch(fol->ai_family)
		{
			case AF_INET: {
				inet_ntop(AF_INET, &(((struct sockaddr_in *)(fol->ai_addr))->sin_addr)
					, xstr, 127);
			} break;
			case AF_INET6: {
				inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)(fol->ai_addr))->sin6_addr)
					, xstr, 127);
			} break;
		}
		printf("lookup: %s\n", xstr);
		
		// NOTE: prioritising IPv4 over IPv6.
		if(best == NULL)
		{
			best = fol;
		} else {
			if(fol->ai_family == AF_INET && best->ai_family == AF_INET6)
				best = fol;
		}
	}
	
	memcpy(sa, best->ai_addr, best->ai_addrlen);
	
	//freeaddrinfo(res);
	return 0;
}

int net_connect(void)
{
	switch(boot_mode & 3)
	{
		case 1: {
			// client only
			struct sockaddr_storage sa;
			if(net_gethost(net_addr, net_port, (struct sockaddr *)&sa, sizeof(sa)))
				return 1;
			
			int sockfd = socket(sa.ss_family, SOCK_STREAM, 0);
			
			if(sockfd == -1)
				return error_perror("net_connect(socket)");
			
			if(connect(sockfd, (struct sockaddr *)&sa, sizeof(sa)) == -1)
				return error_perror("net_connect(connect)");
			
			int yes = 1;
#ifdef WIN32
			if(ioctlsocket(sockfd, FIONBIO, (void *)&yes))
#else
			if(fcntl(sockfd, F_SETFL,
				fcntl(sockfd, F_GETFL) | O_NONBLOCK))
#endif
				return error_perror("net_connect(nonblock)");
			
			if(setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, (void *)&yes, sizeof(yes)) == -1)
				return error_perror("net_connect(nodelay)");
			
			to_client_local.sockfd = sockfd;
		} break;
		
		case 3: {
			// client + server
			to_client_local.sockfd = SOCKFD_LOCAL;
		} break;
	}
	
	return 0;
}

void net_disconnect(void)
{
	int i;
	
	if(to_client_local.sockfd >= 0)
	{
#ifdef WIN32
		closesocket(to_client_local.sockfd);
#else
		close(to_client_local.sockfd);
#endif
		to_client_local.sockfd = -1;
	}
	
	for(i = 0; i < CLIENT_MAX; i++)
		if(to_clients[i].sockfd >= 0)
		{
#ifdef WIN32
			closesocket(to_clients[i].sockfd);
#else
			close(to_clients[i].sockfd);
#endif
			to_clients[i].sockfd = -1;
		}
}

int net_bind(void)
{
	if(net_port == 0)
		return 0;
	
	struct sockaddr_in6 sa6;
	struct sockaddr_in  sa4;
	
	server_sockfd_ipv6 = socket(AF_INET6, SOCK_STREAM, 0);
	server_sockfd_ipv4 = socket(AF_INET,  SOCK_STREAM, 0);
	
	sa6.sin6_family = AF_INET6;
	sa6.sin6_port = htons(net_port);
	sa6.sin6_addr = in6addr_any;
	sa6.sin6_flowinfo = 0;
	sa6.sin6_scope_id = 0;
	
	sa4.sin_family = AF_INET;
	sa4.sin_port = htons(net_port);
	sa4.sin_addr.s_addr = INADDR_ANY;
	
	int yes = 1; // who the hell uses solaris anyway
	int tflags;
	if(setsockopt(server_sockfd_ipv6, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes)) == -1)
	{
		perror("net_bind(reuseaddr.6)");
		server_sockfd_ipv6 = -1;
	}
	yes = 1;
	if(setsockopt(server_sockfd_ipv4, SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes)) == -1)
	{
		perror("net_bind(reuseaddr.4)");
		server_sockfd_ipv4 = -1;
	}
	
	yes = 1;
	if(server_sockfd_ipv6 != -1)
	{
		if(bind(server_sockfd_ipv6, (void *)&sa6, sizeof(sa6)) == -1)
		{
			perror("net_bind(bind.6)");
			server_sockfd_ipv6 = -1;
		} else if(listen(server_sockfd_ipv6, 5) == -1) {
			perror("net_bind(listen.6)");
			server_sockfd_ipv6 = -1;
#ifdef WIN32
		} else if(ioctlsocket(server_sockfd_ipv6,FIONBIO,(void *)&yes)) {
#else
		} else if(fcntl(server_sockfd_ipv6, F_SETFL,
			fcntl(server_sockfd_ipv6, F_GETFL) | O_NONBLOCK)) {
#endif
			perror("net_bind(nonblock.6)");
			server_sockfd_ipv6 = -1;
		}
	}
	
	yes = 1;
	if(server_sockfd_ipv4 != -1)
	{
		if(bind(server_sockfd_ipv4, (void *)&sa4, sizeof(sa4)) == -1)
		{
			perror("net_bind(bind.4)");
			server_sockfd_ipv4 = -1;
		} else if(listen(server_sockfd_ipv4, 5) == -1) {
			perror("net_bind(listen.4)");
			server_sockfd_ipv4 = -1;
#ifdef WIN32
		} else if(ioctlsocket(server_sockfd_ipv4,FIONBIO,(void *)&yes)) {
#else
		} else if(fcntl(server_sockfd_ipv4, F_SETFL,
			fcntl(server_sockfd_ipv4, F_GETFL) | O_NONBLOCK)) {
#endif
			perror("net_bind(nonblock.4)");
			server_sockfd_ipv4 = -1;
		}
	}
	
	if(server_sockfd_ipv4 == -1 && server_sockfd_ipv6 == -1)
		return 1;
	
	printf("sockfds: IPv4 = %i, IPv6 = %i\n"
		, server_sockfd_ipv4
		, server_sockfd_ipv6);
	
	return 0;
}

void net_unbind(void)
{
	if(server_sockfd_ipv4 != -1)
	{
		close(server_sockfd_ipv4);
		server_sockfd_ipv4 = -1;
	}
	
	if(server_sockfd_ipv6 != -1)
	{
		close(server_sockfd_ipv6);
		server_sockfd_ipv6 = -1;
	}
}

int net_init(void)
{
	int i;
	
#ifdef WIN32
	// complete hackjob
	if(WSAStartup(MAKEWORD(2,0), &windows_sucks) != 0)
	{
		fprintf(stderr, "net_init: WSAStartup failed\n");
		return 1;
	}
#endif
	
	for(i = 0; i < CLIENT_MAX; i++)
	{
		to_clients[i].sockfd = -1;
		to_clients[i].head = to_clients[i].tail = NULL;
		to_clients[i].send_head = to_clients[i].send_tail = NULL;
	}
	
	to_server.sockfd = -1;
	to_server.head = to_server.tail = NULL;
	to_server.send_head = to_server.send_tail = NULL;
	
	to_client_local.sockfd = -1;
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
	
#ifdef WIN32
	WSACleanup();
#endif
}
