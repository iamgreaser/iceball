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

int icelua_fn_common_argb_split_to_merged(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 4);
    
    lua_pushinteger(L, 
        ((lua_tointeger(L, 1) & 0xFF) << 16) |
        ((lua_tointeger(L, 2) & 0xFF) << 8) |
        ((lua_tointeger(L, 3) & 0xFF)) |
        ((top < 4 ? 0xFF : (lua_tointeger(L, 4) & 0xFF)) << 24));
	
	return 1;
}

int icelua_fn_common_argb_merged_to_split(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
    
    uint32_t c = lua_tointeger(L, 1);
    
    lua_pushinteger(L, (c >> 24));
    lua_pushinteger(L, (c >> 16) & 0xFF);
    lua_pushinteger(L, (c >> 8) & 0xFF);
    lua_pushinteger(L, (c) & 0xFF);
	
	return 4;
}

int icelua_fn_common_time(lua_State *L)
{
	lua_pushinteger(L, time(NULL));
	return 1;
}
