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

int icelua_fn_common_tcp_connect(lua_State *L) {
	int top = icelua_assert_stack(L, 2, 2);
	
	struct addrinfo hints, *res;
	int ret, sockfd;
	const char *host;
	char port_ch[8];
	int port = 0;

	if (lua_isstring(L, 1)) {
		host = lua_tostring(L, 1);
	} else {
		luaL_error(L, "not a string");
		return 0;
	}

	if (lua_isnumber(L, 2)) {
		port = lua_tonumber(L, 2);
	} else {
		luaL_error(L, "not a number");
		return 0;
	}

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;

	itoa(port, port_ch, 10);

	getaddrinfo(host, port_ch, &hints, &res);
	sockfd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);

	ret = connect(sockfd, res->ai_addr, res->ai_addrlen);
#ifdef WIN32
	int yes = 1;
	if (ioctlsocket(sockfd, FIONBIO, (u_long *)&yes) == -1) {
#else
	if (fcntl(sockfd, F_SETFL, fcntl(sockfd, F_GETFL) | O_NONBLOCK) == -1) {
#endif
		luaL_error(L, "Could not set up a nonblocking connection!");
		return 0;
	}

	if (ret < 0) {
		luaL_error(L, "connect() failed");
		return 0;
	}

	lua_pushnumber(L, sockfd);
	return 1;
}

int icelua_fn_common_tcp_recv(lua_State *L) {
	int top = icelua_assert_stack(L, 1, 1);
	
	int sockfd;
	int n = 0;

	char buf[4096];
	memset(buf, '\0', sizeof(buf));

	if (lua_isnumber(L, 1)) {
		sockfd = lua_tonumber(L, 1);
	} else {
		luaL_error(L, "not a number");
		return 0;
	}

	n = recv(sockfd, buf, sizeof(buf) - 1, 0);
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
	return 1;
}

int icelua_fn_common_tcp_send(lua_State *L) {
	int top = icelua_assert_stack(L, 2, 2);

	int sockfd;
	const char *data;
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

	length = lua_strlen(L, 2);
	sent = send(sockfd, data, length, 0);

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
			lua_pushnil(L);
			return 1;
		}
	}

	if (sent < length)
		lua_pushlstring(L, data + sent, length - sent);
	else
		lua_pushstring(L, "");

	return 1;
}

int icelua_fn_common_tcp_close(lua_State *L) {
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
