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
int icelua_fn_common_json_parse(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	const char *s = lua_tostring(L, 1);
	
	if(s == NULL)
		return luaL_error(L, "not a string");
	
	if(json_parse(L, s))
		return 0;
	else
		return 1;
}

int icelua_fn_common_json_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	const char *fname = lua_tostring(L, 1);
	
	if(fname == NULL)
		return luaL_error(L, "not a string");
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "json");
	lua_pushstring(L, fname);
	lua_call(L, 2, 1);
	
	return 1;
}

int icelua_fn_common_json_write(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	const char *fname = lua_tostring(L, 1);
	lua_remove(L, 1);
	
	if(fname == NULL)
		return luaL_error(L, "json_write: filename not a string");
	if(!(boot_mode & 2) && !path_type_client_writable(path_get_type(fname)))
		return luaL_error(L, "json_write: file not writable!");
	
	json_write(L, fname);
	
	return 0;
}