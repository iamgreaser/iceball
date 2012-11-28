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
int icelua_fn_common_fetch(lua_State *L)
{
	// TODO!
	return 0;
}

int icelua_fn_common_fetch_block(lua_State *L)
{
	// TODO: base this on common.fetch
	// TODO: run this through a network
	
	int top = icelua_assert_stack(L, 2, 2);
	const char *ftype = lua_tostring(L, 1);
	const char *fname = lua_tostring(L, 2);
	
	if(!strcmp(ftype, "lua"))
	{
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "map")) {
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "icemap")) {
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "vxl")) {
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "pmf")) {
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "tga")) {
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "json")) {
		// TODO!
		return 0;
	} else if(!strcmp(ftype, "log")) {
		// TODO!
		return 0;
	} else {
		return luaL_error(L, "unsupported format for fetch");
	}
}
