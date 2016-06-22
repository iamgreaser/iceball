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

char *cfetch_fname = NULL;
char *cfetch_ftype = NULL;

// aux helpers
int icelua_fnaux_fetch_gettype(lua_State *L, const char *ftype)
{
	if(!strcmp(ftype, "lua"))
		return UD_LUA;
	else if(!strcmp(ftype, "map"))
		return UD_MAP;
	else if(!strcmp(ftype, "icemap"))
		return UD_MAP_ICEMAP;
	else if(!strcmp(ftype, "vxl"))
		return UD_MAP_VXL;
	else if(!strcmp(ftype, "pmf"))
		return UD_PMF;
	else if(!strcmp(ftype, "tga"))
		return UD_IMG_TGA;
	else if(!strcmp(ftype, "json"))
		return UD_JSON;
	else if(!strcmp(ftype, "wav"))
		return UD_WAV;
	else if(!strcmp(ftype, "it"))
		return UD_MUS_IT;
	else if(!strcmp(ftype, "bin"))
		return UD_BIN;
	else if(!strcmp(ftype, "png"))
		return UD_IMG_PNG;
	else if(!strcmp(ftype, "log")) {
		// TODO!
		return luaL_error(L, "format not supported yet!");
	} else {
		return luaL_error(L, "unsupported format for fetch");
	}
}

int icelua_fnaux_fetch_immediate(lua_State *L, const char *ftype, const char *fname)
{
	if(!strcmp(ftype, "lua"))
	{
		if(luaL_loadfile(L, fname) != 0)
			return luaL_error(L, "%s", lua_tostring(L, -1));

		return 1;
	} else if(!strcmp(ftype, "map")) {
		map_t *map = NULL;

		map = map_load_icemap(fname);
		if(map == NULL)
			map = map_load_aos(fname);

		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "icemap")) {
		map_t *map = map_load_icemap(fname);

		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "vxl")) {
		map_t *map = map_load_aos(fname);

		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "pmf")) {
		model_t *pmf = model_load_pmf(fname);

		if(pmf == NULL)
			return 0;

		*(model_t **)lua_newuserdata(L, sizeof(void *)) = pmf;
		model_gc_set(L);
		return 1;
	} else if(!strcmp(ftype, "tga")) {
		img_t *img = img_load_tga(fname, L);
		if(img == NULL)
			return 0;

		//*(img_t **)lua_newuserdata(L, sizeof(void *)) = img;
		img_gc_set(L);
		return 1;
	} else if(!strcmp(ftype, "png")) {
		img_t *img = img_load_png(fname, L);
		if(img == NULL)
			return 0;

		//*(img_t **)lua_newuserdata(L, sizeof(void *)) = img;
		img_gc_set(L);
		return 1;
	} else if(!strcmp(ftype, "wav")) {
		wav_t *wav = wav_load(fname);
		if(wav == NULL)
			return 0;

		*(wav_t **)lua_newuserdata(L, sizeof(void *)) = wav;
		wav_gc_set(L);
		return 1;
	} else if(!strcmp(ftype, "it")) {
#ifdef DEDI
		int flen = 0;
		char *d = net_fetch_file(fname, &flen);
		if(d == NULL)
		{
			return 0;
		} else {
			lua_pushlstring(L, d, flen);
			free(d);
			return 1;
		}
#else
		it_module_t *mus = sackit_module_load(fname);
		if(mus == NULL)
			return 0;

		lua_pushlightuserdata(L, mus);
		return 1;
#endif
	} else if(!strcmp(ftype, "bin")) {
		int flen = 0;
		char *d = net_fetch_file(fname, &flen);
		if(d == NULL)
		{
			return 0;
		} else {
			lua_pushlstring(L, d, flen);
			free(d);
			return 1;
		}
	} else if(!strcmp(ftype, "json")) {
		return (json_load(L, fname) ? 0 : 1);
	} else if(!strcmp(ftype, "log")) {
		// TODO!
		return luaL_error(L, "format not supported yet!");
	} else {
		return luaL_error(L, "unsupported format for fetch");
	}
}

// common functions
int icelua_fn_common_fetch_start(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	const char *ftype = lua_tostring(L, 1);
	const char *fname = lua_tostring(L, 2);

	if(L == lstate_server && !path_type_server_readable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot read from there");
	}

	if(L == lstate_server || path_type_client_local(path_get_type(fname)))
	{
		return icelua_fnaux_fetch_immediate(L, ftype, fname);
	} else if(to_client_local.cfetch_udtype != UD_INVALID) {
		return luaL_error(L, "already fetching a file");
	} else {
		// 0x30 flags namelen name[namelen] 0x00
		int blen = strlen(fname);
		if(blen > PATH_LEN_MAX)
			return luaL_error(L, "filename too long (%d > %d)"
				, blen, PATH_LEN_MAX);

		to_client_local.cfetch_udtype = icelua_fnaux_fetch_gettype(L, ftype);
		char buf[PATH_LEN_MAX+3+1];
		buf[0] = 0x30;
		buf[1] = to_client_local.cfetch_udtype;
		buf[2] = blen;
		memcpy(buf+3, fname, blen);
		buf[3+blen] = '\0';

		blen += 3+1;

		cfetch_ftype = strdup(ftype);
		cfetch_fname = strdup(fname);

		net_packet_push(blen, buf, SOCKFD_LOCAL
			, &(to_client_local.send_head), &(to_client_local.send_tail));

		lua_pushboolean(L, 1);
		return 1;
	}
}

int icelua_fn_common_fetch_poll(lua_State *L)
{
	if(L == lstate_server)
		return luaL_error(L, "fetch_poll not supported for C->S transfers");

	if(to_client_local.cfetch_cpos == -1)
	{
		free(cfetch_fname);
		free(cfetch_ftype);
		free(to_client_local.cfetch_ubuf);
		to_client_local.cfetch_ubuf = NULL;
		to_client_local.cfetch_udtype = UD_INVALID;
		to_client_local.cfetch_cpos = 0;
		lua_pushnil(L);
		return 1;
	}

	if(to_client_local.cfetch_ubuf != NULL)
	{
		//printf("Decompressed!\n");
		int ret = 0;

		switch(to_client_local.cfetch_udtype)
		{
			case UD_JSON:
				to_client_local.cfetch_ubuf[to_client_local.cfetch_ulen] = 0;
				ret = (json_parse(L, to_client_local.cfetch_ubuf)
						? 0
						: 1);
				break;
			case UD_LUA:
				ret = (luaL_loadbuffer (L,
					to_client_local.cfetch_ubuf,
					(size_t)to_client_local.cfetch_ulen,
					cfetch_fname)
						? 0
						: 1);
				break;

			case UD_MAP_ICEMAP: {
				map_t *map = map_parse_icemap(
					to_client_local.cfetch_ulen,
					to_client_local.cfetch_ubuf);

				if(map == NULL)
				{
					ret = 0;
					break;
				}

				lua_pushlightuserdata(L, map);
				ret = 1;
			} break;

			case UD_MAP_VXL: {
				map_t *map = map_parse_aos(
					to_client_local.cfetch_ulen,
					to_client_local.cfetch_ubuf);

				if(map == NULL)
				{
					ret = 0;
					break;
				}

				lua_pushlightuserdata(L, map);
				ret = 1;
			} break;

			case UD_MAP: {
				map_t *map = map_parse_icemap(
					to_client_local.cfetch_ulen,
					to_client_local.cfetch_ubuf);
				if(map == NULL)
					map = map_parse_aos(
						to_client_local.cfetch_ulen,
						to_client_local.cfetch_ubuf);

				if(map == NULL)
				{
					ret = 0;
					break;
				}

				lua_pushlightuserdata(L, map);
				ret = 1;
			} break;

			case UD_PMF: {
				model_t *pmf = model_parse_pmf(
					to_client_local.cfetch_ulen,
					to_client_local.cfetch_ubuf);

				if(pmf == NULL)
				{
					ret = 0;
					break;
				}

				*(model_t **)lua_newuserdata(L, sizeof(void *)) = pmf;
				model_gc_set(L);
				ret = 1;
			} break;

			case UD_IMG_TGA: {
				img_t *img = img_parse_tga(
					to_client_local.cfetch_ulen,
					to_client_local.cfetch_ubuf, L);

				if(img == NULL)
				{
					ret = 0;
					break;
				}

				//*(img_t **)lua_newuserdata(L, sizeof(void *)) = img;
				img_gc_set(L);
				ret = 1;
			} break;

			case UD_IMG_PNG: {
				img_t *img = img_parse_png(
					to_client_local.cfetch_ulen,
					to_client_local.cfetch_ubuf, L);

				if(img == NULL)
				{
					ret = 0;
					break;
				}

				//*(img_t **)lua_newuserdata(L, sizeof(void *)) = img;
				img_gc_set(L);
				ret = 1;
			} break;

			case UD_WAV: {
				wav_t *wav = wav_parse(
					to_client_local.cfetch_ubuf,
					to_client_local.cfetch_ulen);

				if(wav == NULL)
				{
					ret = 0;
					break;
				}

				*(wav_t **)lua_newuserdata(L, sizeof(void *)) = wav;
				wav_gc_set(L);
				ret = 1;
			} break;

			case UD_MUS_IT: {
#ifdef DEDI
				lua_pushlstring(L, to_client_local.cfetch_ubuf, to_client_local.cfetch_ulen);
				ret = 1;
#else
				// create temp file (sackit doesn't support loading from memory, at least right now)
				// "Never use this function." i have no other choice
				char *tfname = tempnam(NULL, "ibsit");
				if(tfname == NULL)
				{
					ret = 0;
					break;
				}
				FILE *fp = fopen(tfname, "wb");
				if(fp == NULL)
				{
					ret = 0;
					free(tfname);
					break;
				}
				fwrite(to_client_local.cfetch_ubuf, to_client_local.cfetch_ulen, 1, fp);
				fclose(fp);

				it_module_t *mus = sackit_module_load(tfname);
				if(mus == NULL)
				{
					ret = 0;
				} else {
					ret = 1;
					lua_pushlightuserdata(L, mus);
				}

				free(tfname);
#endif
			} break;

			case UD_BIN: {
				lua_pushlstring(L, to_client_local.cfetch_ubuf, to_client_local.cfetch_ulen);
				ret = 1;
			} break;

			default:
				fprintf(stderr, "EDOOFUS: invalid fetch type %i!\n",
					to_client_local.cfetch_udtype);
				fflush(stderr);
				abort();
				break;
		}

		free(cfetch_fname);
		free(cfetch_ftype);
		free(to_client_local.cfetch_ubuf);
		to_client_local.cfetch_ubuf = NULL;
		to_client_local.cfetch_udtype = UD_INVALID;

		if(ret)
		{
			lua_pushinteger(L, to_client_local.cfetch_clen);
			lua_pushinteger(L, to_client_local.cfetch_ulen);
			lua_pushnumber(L, 1.0);
			ret += 3;
		}

		return ret;
	}

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if((boot_mode & IB_MAIN_LOADED) ? run_game_cont1() : run_game_cont2())
		return luaL_error(L, "quit flag asserted!");
#endif

	lua_pushboolean(L, 0);
	if(to_client_local.cfetch_cbuf == NULL)
	{
		lua_pushnil(L);
		lua_pushnil(L);
		lua_pushnumber(L, 0.0);
	} else {
		lua_pushinteger(L, to_client_local.cfetch_clen);
		lua_pushinteger(L, to_client_local.cfetch_ulen);
		lua_pushnumber(L, ((double)to_client_local.cfetch_cpos)
			/((double)to_client_local.cfetch_clen));
	}
	return 4;
}

int icelua_fn_common_fetch_block(lua_State *L)
{
	//printf("fetch block\n");
	fflush(stdout);

	int top = icelua_assert_stack(L, 2, 2);

	//printf("fetch block\n");

	// local obj = common.fetch_start(ftype, x)
	lua_pushcfunction(L, icelua_fn_common_fetch_start);
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_call(L, 2, 1);

	// if obj ~= true then return obj end
	if((!lua_isboolean(L, -1)) || !lua_toboolean(L, -1))
		return 1;

	lua_pop(L, 1);

	// while true do
	for(;;)
	{
		// local obj = common.fetch_poll()
		lua_pushcfunction(L, icelua_fn_common_fetch_poll);
		lua_call(L, 0, 1);
		// if obj ~= false then return obj end
		if(!lua_isboolean(L, -1) || lua_toboolean(L, -1))
			return 1;
		// if obj == nil then return nil end
		if(lua_isnil(L, -1))
			return 1;
		lua_pop(L, 1);
	}
	// end
}

