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

// common functions
int icelua_fn_common_map_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 2);
	const char *fname = lua_tostring(L, 1);
	const char *type = "auto";
	if(top >= 2)
		type = lua_tostring(L, 2);
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	if(!strcmp(type, "auto"))
	{
		lua_pushstring(L, "map");
	} else if(!strcmp(type, "vxl")) {
		lua_pushstring(L, "vxl");
	} else if(!strcmp(type, "icemap")) {
		lua_pushstring(L, "icemap");
	} else {
		return luaL_error(L, "not a valid map type");
	}
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	return 1;
}

int icelua_fn_common_map_new(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	int xlen = lua_tointeger(L, 1);
	int ylen = lua_tointeger(L, 2);
	int zlen = lua_tointeger(L, 3);
	
	if(xlen < 4 || ylen < 4 || zlen < 4)
		return luaL_error(L, "map size too small");
	
	// XXX: shouldn't this be in map.c?
	map_t *map = (map_t*)malloc(sizeof(map_t));
	if(map == NULL)
	{
		int err = errno;
		return luaL_error(L, "could not allocate map: %d / %s", err, strerror(err));
	}
	map->udtype = UD_MAP;
	map->xlen = xlen;
	map->ylen = ylen;
	map->zlen = zlen;
	map->pillars = (uint8_t**)malloc(xlen*zlen*sizeof(uint8_t *));
	if(map->pillars == NULL)
	{
		int err = errno;
		map_free(map);
		return luaL_error(L, "could not allocate map->pillars: %d / %s", err, strerror(err));
	}
	
	int x,z,pi;
	int b = map->ylen-2;
	for(z = 0, pi = 0; z < map->zlen; z++)
	for(x = 0; x < map->xlen; x++, pi++)
	{
		uint8_t *p = map->pillars[pi] = (uint8_t*)malloc(16);
		// TODO: check if NULL
		uint8_t v = (uint8_t)(x^z);
		*(p++) = 1; *(p++) = 0; *(p++) = 0; *(p++) = 0;
		*(p++) = 0; *(p++) = b; *(p++) = b; *(p++) = 0;
		*(p++) = v; *(p++) = v; *(p++) = v; *(p++) = 1;
	}
#ifndef DEDI
	map->visible_chunks_arr = NULL;
	render_init_visible_chunks(map, 0, 0);
#endif
	
	lua_pushlightuserdata(L, map);
	return 1;
}

int icelua_fn_common_map_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	map_t *map = (map_t*)lua_touserdata(L, 1);
	if(map == NULL || map->udtype != UD_MAP)
		return luaL_error(L, "not a map");
	
	map_free(map);
	
	return 0;
}

int icelua_fn_common_map_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	map_t *map = (map_t*)lua_touserdata(L, 1);
	if((map == NULL || map->udtype != UD_MAP) && !lua_isnil(L, 1))
		return luaL_error(L, "not a map");
	
	if(L == lstate_server)
		svmap = map;
	else if(L == lstate_client)
		clmap = map;
	
	return 0;
}

int icelua_fn_common_map_get(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	map_t *map = NULL;
	
	if(L == lstate_server)
		map = svmap;
	else if(L == lstate_client)
		map = clmap;
	
	if(map == NULL)
		return 0;
	
	lua_pushlightuserdata(L, map);
	return 1;
}

int icelua_fn_common_map_save(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 3);
	
	map_t *map = (map_t*)lua_touserdata(L, 1);
	if(map == NULL || map->udtype != UD_MAP)
		return luaL_error(L, "not a map");
	const char *fname = lua_tostring(L, 2);
	const char *type = "icemap";
	if(top >= 3)
		type = lua_tostring(L, 3);
	
	if(L != lstate_server && !bin_storage_allowed)
		return luaL_error(L, "saving disabled");
	
	if(L == lstate_server
		? !path_type_server_writable(path_get_type(fname))
		: !path_type_client_writable(path_get_type(fname)))
			return luaL_error(L, "cannot write to there %d",path_get_type(fname));
	
	if(!strcmp(type, "vxl"))
	{
		return luaL_error(L, "cannot save to vxl, sorry!");
	} else if(!strcmp(type, "icemap")) {
		if(map_save_icemap(map, fname))
			return luaL_error(L, "map save failed, check the console");
	} else {
		return luaL_error(L, "not a valid map type");
	}
	
	return 0;
}

int icelua_fn_common_map_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// if no map, just give off nils
	if(map == NULL || map->udtype != UD_MAP)
	{
		return 0;
	} else {
		lua_pushinteger(L, map->xlen);
		lua_pushinteger(L, map->ylen);
		lua_pushinteger(L, map->zlen);
		return 3;
	}
}

int icelua_fn_common_map_pillar_get(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	int px, pz;
	int i;
	
	px = lua_tointeger(L, 1);
	pz = lua_tointeger(L, 2);
	
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// if no map, return nil
	if(map == NULL || map->udtype != UD_MAP)
		return 0;
	
	// get a pillar
	uint8_t *p = map->pillars[(pz&(map->zlen-1))*map->xlen+(px&(map->xlen-1))];
	
	// build the list
	int llen = 4*((255&(int)*p)+1);
	lua_createtable(L, llen, 0);
	p += 4;
	
	for(i = 1; i <= llen; i++)
	{
		lua_pushinteger(L, i);
		lua_pushinteger(L, *(p++));
		lua_settable(L, -3);
	}
	
	return 1;
}

int icelua_fn_common_map_pillar_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	int px, pz, tlen;
	int i;
	
	px = lua_tointeger(L, 1);
	pz = lua_tointeger(L, 2);
	if(!lua_istable(L, 3))
		return luaL_error(L, "expected a table, got something else");
	tlen = lua_objlen(L, 3);
	
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// if no map, ignore (for now)
	if(map == NULL || map->udtype != UD_MAP)
		return 0;
	
	// validate that the table is not TOO large and is 4-byte aligned wrt size
	if((tlen&3) || tlen > 1024)
		return luaL_error(L, "table length %d invalid", tlen);
	
	// validate the table's input range
	for(i = 0; i < tlen; i++)
	{
		lua_pushinteger(L, 1+i);
		lua_gettable(L, 3);
		int v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		if(v < 0 || v > 255)
			return luaL_error(L, "value at index %d out of unsigned byte range (%d)"
				, 1+i, v);
	}
	
	// validate the table data
	i = 0;
	for(;;)
	{
		lua_pushinteger(L, 1+i+0);
		lua_gettable(L, 3);
		lua_pushinteger(L, 1+i+1);
		lua_gettable(L, 3);
		lua_pushinteger(L, 1+i+2);
		lua_gettable(L, 3);
		lua_pushinteger(L, 1+i+3);
		lua_gettable(L, 3);
		int n = lua_tointeger(L, -4);
		int s = lua_tointeger(L, -3);
		int e = lua_tointeger(L, -2);
		int a = lua_tointeger(L, -1);
		lua_pop(L, 4);
		
		//printf("%i %i | %i %i | %i %i %i %i\n",px,pz,i,tlen,n,s,e,a);
		
		// Note, we are not supporting the shenanigans you can do in VOXLAP.
		// Especially considering that editing said shenanigans causes issues.
		// Also noting that said shenanigans weren't all that exploited,
		// VOXLAP automatically corrects shenanigans when you edit stuff,
		// and pyspades has no support for such shenanigans.
		if(e+1 < s)
			return luaL_error(L, "pillar has end+1 < start (%d < %d)"
					, e+1, s);
		if(i != 0 && s < a)
			return luaL_error(L, "pillar has start < air (%d < %d)"
					, s, a);
		if(n != 0 && n-1 < e-s+1)
			return luaL_error(L, "pillar has length < top length (%d < %d)"
					, n-1, e-s+1);
		
		
		// NOTE: this doesn't validate the BGRT (colour/type) entries.
		int la = 0;
		if(n == 0)
		{
			int exlen = (e-s+1)*4+i+4;
			if(exlen != tlen)
				return luaL_error(L, "pillar table len should be %d, got %d instead"
					, exlen, tlen);
			break;
		} else {
			i += 4*n;
			// should always be colour on the bottom!
			if(i > tlen-4)
				return luaL_error(L, "pillar table overflow when validating");
		
		}
	}
	
	// expand the pillar data if necessary
	int idx = (pz&(map->zlen-1))*map->xlen+(px&(map->xlen-1));
	uint8_t *p = map->pillars[idx];
	if((p[0]+1)*4 < tlen)
	{
		p = map->pillars[idx] = (uint8_t*)realloc(p, tlen+4);
		p[0] = (tlen>>2)-1;
	}
	
	// transfer the table data
	p += 4;
	for(i = 1; i <= tlen; i++)
	{
		lua_pushinteger(L, i);
		lua_gettable(L, 3);
		*(p++) = (uint8_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}

#ifndef DEDI
	render_map_mark_chunks_as_dirty(map, px, pz);
#endif
	
	force_redraw = 1;
	
	return 0;
}

// client functions
int icelua_fn_client_map_fog_get(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
#ifdef DEDI
	return luaL_error(L, "lm: why the hell is this being called in the dedi version?");
#else
	lua_pushinteger(L, (fog_color>>16)&255);
	lua_pushinteger(L, (fog_color>>8)&255);
	lua_pushinteger(L, (fog_color)&255);
	lua_pushnumber(L, fog_distance);
#endif
	
	return 4;
}

int icelua_fn_client_map_fog_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 4, 4);

	map_t *map = (L == lstate_server ? svmap : clmap);
	
#ifdef DEDI
	return luaL_error(L, "lm: why the hell is this being called in the dedi version?");
#else
	int r = lua_tointeger(L, 1)&255;
	int g = lua_tointeger(L, 2)&255;
	int b = lua_tointeger(L, 3)&255;
	float old_dist = fog_distance;
	fog_distance = lua_tonumber(L, 4);
	if(fog_distance < 5.0f)
		fog_distance = 5.0f;
	if(fog_distance > FOG_MAX_DISTANCE)
		fog_distance = FOG_MAX_DISTANCE;
	
#ifndef DEDI
	// TODO: take advantage of realloc()
	if(fog_distance != old_dist)
		render_init_visible_chunks(map, 0, 0);
#endif
	
	fog_color = (r<<16)|(g<<8)|b;
	force_redraw = 1;
#endif

	return 4;
}

int icelua_fn_common_map_mapents_get(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// If no entities, return nil
	if(map == NULL || map->udtype != UD_MAP || map->entities == NULL)
		return 0;
	
	lua_pushlstring(L, map->entities, map->entities_size);
	
	return 1;
}

int icelua_fn_common_map_mapents_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	size_t ents_size;
	const char *ents = lua_tolstring(L, 1, &ents_size);
	if(ents == NULL)
		return luaL_error(L, "not a string");
	
	// If no map, error
	if(map == NULL || map->udtype != UD_MAP)
		return luaL_error(L, "no map");
	
	if (!map_set_mapents(map, ents, ents_size))
	{
		return luaL_error(L, "error setting MapEnts");
	}
	
	return 0;
}
