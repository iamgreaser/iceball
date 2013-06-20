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

int icelua_fn_common_bin_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");

	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "bin");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);

	return 1;
}

int icelua_fn_common_bin_save(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);

	size_t fdlen = 0;
	const char *fname = lua_tostring(L, 1);
	const char *fdata = lua_tolstring(L, 2, &fdlen);

	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	if(fdata == NULL)
		return luaL_error(L, "data must be a string");
	
	if(L != lstate_server && !bin_storage_allowed)
		return luaL_error(L, "saving disabled");

	if(L == lstate_server
		? !path_type_server_writable(path_get_type(fname))
		: !path_type_client_writable(path_get_type(fname)))
			return luaL_error(L, "cannot write to there %d",path_get_type(fname));
	
	FILE *fp = fopen(fname, "wb");
	fwrite(fdata, fdlen, 1, fp);
	fclose(fp);

	lua_pushboolean(L, 1);

	return 1;
}

