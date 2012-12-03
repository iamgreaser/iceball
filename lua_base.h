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

int icelua_fn_base_loadfile(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	const char *fname = lua_tostring(L, 1);
	
	if(L == lstate_server
		? !path_type_server_readable(path_get_type(fname))
		: !path_type_client_readable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot read from there");
	}
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "lua");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	return 1;
}

int icelua_fn_base_dofile(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	lua_pushcfunction(L, icelua_fn_base_loadfile);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);
	
	// TODO: pcall this
	lua_call(L, 0, 0);
	
	return 0;
}
