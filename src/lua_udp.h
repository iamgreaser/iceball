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

#if !defined(_MSC_VER) || (_MSC_VER <= 1900)
const char *inet_ntop(int af, const void *src, char *dst, socklen_t cnt);
#endif

int whitelist_validate(const char *name, int port);

int icelua_fn_common_udp_open(lua_State *L) {
	int top = icelua_assert_stack(L, 0, 0);

	int ret, sockfd;
	const char *host;
	char port_ch[18];
	int port = 0;

	// TODO: support IPv6
	sockfd = socket(AF_INET, SOCK_DGRAM, 0);
	if(sockfd == -1)
		return 0;
#ifdef WIN32
	int yes = 1;
	if (ioctlsocket(sockfd, FIONBIO, (u_long *)&yes) == -1) {
#else
	if (fcntl(sockfd, F_SETFL, fcntl(sockfd, F_GETFL) | O_NONBLOCK) == -1) {
#endif
		return luaL_error(L, "Could not set up a nonblocking connection!");
	}

	lua_pushnumber(L, sockfd);
	return 1;
}

int icelua_fn_common_udp_recvfrom(lua_State *L) {
	int top = icelua_assert_stack(L, 1, 1);

	int sockfd;
	int n = 0;

	struct sockaddr_in saddr;
	char buf[4096];
	memset(buf, '\0', sizeof(buf));

	if (lua_isnumber(L, 1)) {
		sockfd = lua_tonumber(L, 1);
	} else {
		luaL_error(L, "not a number");
		return 0;
	}

	socklen_t sadlen = sizeof(saddr);
	n = recvfrom(sockfd, buf, sizeof(buf) - 1, 0, (struct sockaddr *)&saddr, &sadlen);
	if (n == -1) {
#ifdef WIN32
		int err = WSAGetLastError();
		if (err != WSAEWOULDBLOCK) {
#else
		int err = errno;
		if (err != EAGAIN && err != EWOULDBLOCK) {
#endif
			lua_pushboolean(L, 0);
			return 1;
#ifdef WIN32
		} else if (err == WSAEWOULDBLOCK) {
#else
		} else if (err == EWOULDBLOCK || err == EAGAIN) {
#endif
			lua_pushstring(L, "");
			return 1;
		}
	}

	lua_pushlstring(L, buf, n);

	// TODO: support IPv6
	char dst_buf[50];
	const char *astr = inet_ntop(AF_INET, &(saddr.sin_addr.s_addr), dst_buf, sizeof(dst_buf)-1);
	if(astr == NULL)
		lua_pushnil(L);
	else
		lua_pushstring(L, astr);

	lua_pushinteger(L, ntohs(saddr.sin_port));

	return 3;
}

int icelua_fn_common_udp_sendto(lua_State *L) {
	int top = icelua_assert_stack(L, 4, 4);

	int sockfd;
	struct addrinfo hints, *res;
	char port_ch[18];
	const char *data;
	const char *host;
	int port = 0;
	int length;
	int sent;

	if (lua_isnumber(L, 1)) {
		sockfd = lua_tonumber(L, 1);
	} else {
		luaL_error(L, "not a number");
		return 0;
	}

	if (lua_isstring(L, 2)) {
		data = lua_tostring(L, 2);
	} else {
		luaL_error(L, "not a string");
		return 0;
	}

	if (lua_isstring(L, 3)) {
		host = lua_tostring(L, 3);
	} else {
		return luaL_error(L, "not a string");
	}

	if (lua_isnumber(L, 4)) {
		port = lua_tonumber(L, 4);
	} else {
		return luaL_error(L, "not a number");
	}

	if(L == lstate_client && !whitelist_validate(host, port))
		return luaL_error(L, "address/port not on whitelist!");

	// FIXME: the host lookup result should ideally be cached
	// FIXME: make note of the address family used / socktype
	// TODO: support IPv6
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_DGRAM;

	snprintf(port_ch, 17, "%u", port);

	sent = 0;
	length = lua_strlen(L, 2);
	if(getaddrinfo(host, port_ch, &hints, &res) == 0)
	{
		sent = (res == NULL ? 0 : sendto(sockfd, data, length, 0, res->ai_addr, res->ai_addrlen));
		if(res != NULL) freeaddrinfo(res);
	}

	if (sent <= 0) {
#ifdef WIN32
		int err = WSAGetLastError();
		if (err != WSAEWOULDBLOCK) {
#else
		int err = errno;
		if (err != EAGAIN && err != EWOULDBLOCK) {
#endif
			lua_pushboolean(L, 0);
			return 1;
#ifdef WIN32
		} else if (err == WSAEWOULDBLOCK) {
#else
		} else if (err == EWOULDBLOCK || err == EAGAIN) {
#endif
			lua_pushlstring(L, data, length);
			return 1;
		}
	}

	if (sent < length)
		lua_pushlstring(L, data + sent, length - sent);
	else
		lua_pushstring(L, "");

	return 1;
}

int icelua_fn_common_udp_close(lua_State *L) {
	int top = icelua_assert_stack(L, 1, 1);

	int sockfd;

	if (lua_isnumber(L, 1)) {
		sockfd = lua_tonumber(L, 1);
	} else {
		luaL_error(L, "not a number");
		return 0;
	}

	close(sockfd);
	return 0;
}
