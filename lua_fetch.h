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

const char *cfetch_fname = NULL;
const char *cfetch_ftype = NULL;

// aux helpers
int icelua_fnaux_common_fetch_immediate(lua_State *L, const char *ftype, const char *fname)
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
		
		lua_pushlightuserdata(L, pmf);
		return 1;
	} else if(!strcmp(ftype, "tga")) {
		img_t *img = img_load_tga(fname);
		if(img == NULL)
			return 0;
		
		lua_pushlightuserdata(L, img);
		return 1;
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
/*
success = common.fetch_start(ftype, fname)
	initiates a file fetch
	
	"ftype" is one of the following:
	- "lua": lua script
	- "map": map (autodetect)
	- "icemap": map (icemap) - in-memory maps are serialised as THIS.
	- "vxl": map (vxl) - CANNOT SAVE IN THIS FORMAT.
	- "pmf": pmf model
	- "tga": tga image
	- "json": json data
	- "log": log data (TODO)
	- "wav": wav sound (TODO)
	
	for the server, this just loads the file from the disk.
	
	for the client, all clsave/% stuff is taken from the disk,
	but all other files are downloaded from the server.
	
	returns true if the fetch has started,
	or false if there is something already in the queue.
*/
int icelua_fn_common_fetch_start(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	const char *ftype = lua_tostring(L, 1);
	const char *fname = lua_tostring(L, 2);
	
	if(L == lstate_server
		? !path_type_server_readable(path_get_type(fname))
		: !path_type_client_readable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot read from there");
	}
	
	if(L == lstate_server || path_type_client_local(path_get_type(fname)))
	{
		return icelua_fnaux_common_fetch_immediate(L, ftype, fname);
	} else {
		// TODO: send a fetch request to the server
		
		lua_pushboolean(L, 1);
		return 1;
	}
}

/*
obj, csize, usize, amount = common.fetch_poll()
	polls the 
	"obj" is one of the following:
	- "nil" if transfer aborted or nothing is being fetched
	  - in this case, all other fields will be nil
	- "false" if still downloading
	- the object you requested
	  - in this case, another poll will just return nils
	
	"amount" is in the range 0 <= "amount" <= 1,
	and indicates how much is downloaded
	"csize" is the compressed size of the file
	"usize" is the uncompressed size
	
	note, all vxl maps will be converted to icemap before sending.
*/
int icelua_fn_common_fetch_poll(lua_State *L)
{
	if(L == lstate_server)
		return luaL_error(L, "fetch_poll not supported for C->S transfers");
	
	// TODO!
	return icelua_fnaux_common_fetch_immediate(L, cfetch_ftype, cfetch_fname);
	//lua_pushboolean(L, 0);
	//return 1;
}

int icelua_fn_common_fetch_block(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	
	// local obj = common.fetch_start(ftype, x)
	lua_pushcfunction(L, icelua_fn_common_fetch_start);
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_call(L, 2, 1);
	
	cfetch_ftype = lua_tostring(L, 1);
	cfetch_fname = lua_tostring(L, 2);
	
	// if obj ~= true then return obj end
	if((!lua_isboolean(L, -1)) || !lua_toboolean(L, -1))
		return 1;
	
	lua_pop(L, 1);
	
	// while true do
	for(;;)
	{
		// TODO: move this to the bottom.
		// yield()
		if((boot_mode & 4) ? run_game_cont1() : run_game_cont2())
			return luaL_error(L, "quit flag asserted!");
		
		// local obj = common.fetch_poll()
		lua_pushcfunction(L, icelua_fn_common_fetch_poll);
		lua_call(L, 0, 1);
		
		// if obj ~= false then return obj end
		if((!lua_isboolean(L, -1)) || lua_toboolean(L, -1))
			return 1;
		
		lua_pop(L, 1);
	}
	// end
}
