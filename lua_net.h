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

/*
str = common.net_pack(fmt, ...)
	packs data into a string
	
	format is as such:
	b/B = signed/unsigned 8-bit
	h/H = signed/unsigned 16-bit
	i/I = signed/unsigned 32-bit
	f = single-precision 32-bit float
	d = double-precision 64-bit float
	z = zero-terminated string
	#s = fixed-length string (replace # with a decimal number)

..., remain = common.net_unpack(fmt, str)
	unpacks data from a string
	
	will attempt to decode from start to end
	
	"remain" is the remainder of the string which was not decoded
	
	returns nil for fields that could not be decoded
*/

int icelua_fnaux_net_packlen(lua_State *L, const char *fmt, int top)
{
	const char *v = fmt;
	int p = 2;
	int n = 0;
	int len = 0;
	
	while(*v != '\0')
	{
		if(*v >= '0' && *v <= '9')
		{
			n = n*10 + (*(v++) - '0');
		} else switch(*(v++)) {
			case 'b':
			case 'B':
				p++;
				len += 1;
				break;
			case 'h':
			case 'H':
				p++;
				len += 2;
				break;
			case 'i':
			case 'I':
				p++;
				len += 4;
				break;
			case 'f':
				p++;
				len += 4;
				break;
			case 'd':
				p++;
				len += 8;
				break;
			case 's':
				p++;
				len += n;
				n = 0;
				break;
			case 'z':
				if(p <= top && lua_isstring(L, p))
					len += strlen(lua_tostring(L, p))+1;
				else
					len += 1;
				p++;
				break;
			default:
				fprintf(stderr, "net pack format: unexpected char\n");
				return -1;
		}
	}
	
	return len;
}

int icelua_fn_common_net_pack(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 99999);
	
	const char *fmt = lua_tostring(L, 1);
	if(fmt == NULL)
		return luaL_error(L, "not a string");
	
	const char *v = fmt;
	int p = 2;
	int n = 0;
	
	int xint;
	float xfloat;
	double xdouble;
	
	int slen = icelua_fnaux_net_packlen(L, fmt, top);
	if(slen < 0)
		return luaL_error(L, "invalid pack format");
	char *sbuf = malloc(slen+1);
	// TODO: check if NULL
	char *sstop = sbuf+slen;
	*sstop = '\0';
	
	char *s = sbuf;
	
	while(*v != '\0')
	{
		if(*v >= '0' && *v <= '9')
		{
			n = n*10 + (*(v++) - '0');
		} else switch(*(v++)) {
			case 'b':
			case 'B':
				xint = lua_tointeger(L, p++);
				*(s++) = xint & 0xFF;
				break;
			case 'h':
			case 'H':
				xint = lua_tointeger(L, p++);
				*(s++) = xint & 0xFF;
				*(s++) = (xint>>8) & 0xFF;
				break;
			case 'i':
			case 'I':
				xint = lua_tointeger(L, p++);
				*(s++) = xint & 0xFF;
				*(s++) = (xint>>8) & 0xFF;
				*(s++) = (xint>>16) & 0xFF;
				*(s++) = (xint>>24) & 0xFF;
				break;
			case 'f':
				xfloat = lua_tointeger(L, p++);
				xint = *(int *)(float *)&xfloat;
				*(s++) = xint & 0xFF;
				*(s++) = (xint>>8) & 0xFF;
				*(s++) = (xint>>16) & 0xFF;
				*(s++) = (xint>>24) & 0xFF;
				break;
			case 'd':
				xdouble = lua_tointeger(L, p++);
				xint = ((int *)(float *)&xdouble)[0];
				*(s++) = xint & 0xFF;
				*(s++) = (xint>>8) & 0xFF;
				*(s++) = (xint>>16) & 0xFF;
				*(s++) = (xint>>24) & 0xFF;
				xint = ((int *)(float *)&xdouble)[4];
				*(s++) = xint & 0xFF;
				*(s++) = (xint>>8) & 0xFF;
				*(s++) = (xint>>16) & 0xFF;
				*(s++) = (xint>>24) & 0xFF;
				break;
			case 's': {
				size_t slen;
				const char *xstr = lua_tolstring(L, p++, &slen);
				memset(s, 0, n);
				if(xstr != NULL)
					memcpy(s, xstr, ((int)slen <= n ? (int)slen : n));
				s += n;
				n = 0;
			} break;
			case 'z': {
				const char *xstr = lua_tostring(L, p++);
				if(xstr != NULL)
				{
					int slen = strlen(xstr);
					memcpy(s, xstr, slen);
					s += slen;
				}
				*(s++) = '\0';
			} break;
			default:
				fprintf(stderr, "net_pack[EDOOFUS]: unexpected char\n");
				fflush(stderr);
				abort();
		}
	}
	
	if(s != sstop)
	{
		//fprintf(stderr, "%i\n", (int)(sstop-s));
		fprintf(stderr, "net_pack[EDOOFUS]: s != sstop!\n");
		fflush(stderr);
		abort();
	}
	lua_pushlstring(L, sbuf, slen);
	free(sbuf);
	return 1;
}

int icelua_fn_common_net_unpack(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	
	const char *fmt = lua_tostring(L, 1);
	if(fmt == NULL)
		return luaL_error(L, "not a string");
	size_t bsize;
	const char *str = lua_tolstring(L, 2, &bsize);
	if(str == NULL)
		return luaL_error(L, "not a string");
	
	const char *v = fmt;
	
	const char *s = str;
	int p = 0;
	int n = 0;
	
	int xint;
	float xfloat;
	double xdouble;
	
	while(*v != '\0')
	{
		if(*v >= '0' && *v <= '9')
		{
			n = n*10 + (*(v++) - '0');
		} else switch(*(v++)) {
			case 'b':
				xint = *(int8_t *)s;
				s++;
				lua_pushinteger(L, xint);
				p++;
				break;
			case 'B':
				xint = *(uint8_t *)s;
				s++;
				lua_pushinteger(L, xint);
				p++;
				break;
			case 'h':
				xint = *(int16_t *)s;
				s += 2;
				lua_pushinteger(L, xint);
				p++;
				break;
			case 'H':
				xint = *(uint16_t *)s;
				s += 2;
				lua_pushinteger(L, xint);
				p++;
				break;
			case 'i':
				xint = *(int32_t *)s;
				s += 4;
				lua_pushinteger(L, xint);
				p++;
				break;
			case 'I':
				xint = *(uint32_t *)s;
				s += 4;
				lua_pushinteger(L, xint);
				p++;
				break;
			case 'f':
				xfloat = *(float *)s;
				s += 4;
				lua_pushnumber(L, xfloat);
				p++;
				break;
			case 'd':
				xdouble = *(double *)s;
				s += 8;
				lua_pushnumber(L, xdouble);
				p++;
				break;
			case 's': {
				lua_pushlstring(L, s+n, n);
				p++;
				break;
			} break;
			case 'z': {
				int slen = strlen(s);
				lua_pushstring(L, s);
				s += slen+1;
				p++;
				break;
			} break;
			default:
				lua_pop(L, p);
				return luaL_error(L, "net_unpack: unexpected char\n");
		}
	}
	
	lua_pushlstring(L, s, (size_t)(bsize-(int)(s-str)));
	return p+1;
}

int icelua_fn_common_net_send(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	
	size_t bsize;
	const char *str = lua_tolstring(L, 2, &bsize);
	if(str == NULL)
		return luaL_error(L, "not a string");
	
	// TODO: incorporate the sockfd field
	//net_packet_push(int len, uint8_t *data, packet_t **head, packet_t **tail);
	if(L != lstate_server)
	{
		net_packet_push_lua((int)bsize, str, -1, &pkt_client_send_head, &pkt_client_send_tail);
		lua_pushboolean(L, 1);
		return 1;
	} else {
		int sockfd = -1;
		if(lua_isboolean(L, 1) && lua_toboolean(L, 1))
		{
			sockfd = -2;
		} else if(lua_isnumber(L, 1)){
			sockfd = lua_tonumber(L, 1);
			if(sockfd < 0)
				sockfd = -1;
		}
		if(sockfd == -1)
			return 0;
		
		net_packet_push_lua((int)bsize, str, sockfd, &pkt_server_send_head, &pkt_server_send_tail);
		lua_pushboolean(L, 1);
		return 1;
	}
}

int icelua_fn_common_net_recv(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
	if(L == lstate_server)
	{
		packet_t *pkt = net_packet_pop(&pkt_server_recv_head, &pkt_server_recv_tail);
		if(pkt == NULL)
			return 0;
		
		if(pkt->data[0] >= 0x40 && pkt->data[0] <= 0x7E)
			lua_pushlstring(L, &pkt->data[1], pkt->len-1);
		else if(pkt->data[0] == 0x7F)
			lua_pushlstring(L, &pkt->data[3], pkt->len-3);
		else {
			fprintf(stderr, "EDOOFUS: SYSTEM PACKET *MUST NOT* REACH common.net_recv!\n");
			fflush(stderr);
			abort();
		}
		
		if(pkt->sockfd == -1)
			lua_pushnil(L);
		else if(pkt->sockfd < 0)
			lua_pushboolean(L, 1);
		else
			lua_pushinteger(L, pkt->sockfd);
		
		return 2;
	} else {
		packet_t *pkt = net_packet_pop(&pkt_client_recv_head, &pkt_client_recv_tail);
		if(pkt == NULL)
			return 0;
		
		if(pkt->data[0] >= 0x40 && pkt->data[0] <= 0x7E)
			lua_pushlstring(L, &pkt->data[1], pkt->len-1);
		else if(pkt->data[0] == 0x7F)
			lua_pushlstring(L, &pkt->data[3], pkt->len-3);
		else {
			fprintf(stderr, "EDOOFUS: NON-Lua PACKET *MUST NOT* REACH common.net_recv!\n");
			fflush(stderr);
			abort();
		}
		
		lua_pushnil(L);
		return 2;
	}
}
