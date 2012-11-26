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

// client functions
int icelua_fn_client_img_blit(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 8);
	int dx, dy, bw, bh, sx, sy;
	uint32_t color;
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL)
		return luaL_error(L, "not an image");
	
	dx = lua_tointeger(L, 2);
	dy = lua_tointeger(L, 3);
	bw = (top < 4 ? img->head.width : lua_tointeger(L, 4));
	bh = (top < 5 ? img->head.height : lua_tointeger(L, 5));
	sx = (top < 6 ? 0 : lua_tointeger(L, 6));
	sy = (top < 7 ? 0 : lua_tointeger(L, 7));
	color = (top < 8 ? 0xFFFFFFFF : (uint32_t)lua_tointeger(L, 8));
	
	render_blit_img(screen->pixels, screen->w, screen->h, screen->pitch/4,
		img, dx, dy, bw, bh, sx, sy, color);
	
	return 0;
}

// common functions
int icelua_fn_common_img_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	img_t *img = img_load_tga(fname);
	if(img == NULL)
		return 0;
	
	lua_pushlightuserdata(L, img);
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 3;
}

int icelua_fn_common_img_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL)
		return luaL_error(L, "not an image");
	
	img_free(img);
	
	return 0;
}

int icelua_fn_common_img_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL)
		return luaL_error(L, "not an image");
	
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 2;
}
