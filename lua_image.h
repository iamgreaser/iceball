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
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	
	dx = lua_tointeger(L, 2);
	dy = lua_tointeger(L, 3);
	bw = (top < 4 ? img->head.width : lua_tointeger(L, 4));
	bh = (top < 5 ? img->head.height : lua_tointeger(L, 5));
	sx = (top < 6 ? 0 : lua_tointeger(L, 6));
	sy = (top < 7 ? 0 : lua_tointeger(L, 7));
	color = (top < 8 ? 0xFFFFFFFF : (uint32_t)lua_tointeger(L, 8));
	
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	render_blit_img(screen->pixels, screen->w, screen->h, screen->pitch/4,
		img, dx, dy, bw, bh, sx, sy, color);
#endif
	
	return 0;
}

int icelua_fn_client_img_blit_to(lua_State *L)
{
	int top = icelua_assert_stack(L, 4, 9);
	int dx, dy, bw, bh, sx, sy;
	uint32_t color;
	
	img_t *dest = lua_touserdata(L, 1);
	if(dest == NULL || dest->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	img_t *source = lua_touserdata(L, 2);
	if(source == NULL || source->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	
	dx = lua_tointeger(L, 3);
	dy = lua_tointeger(L, 4);
	bw = (top < 5 ? source->head.width : lua_tointeger(L, 5));
	bh = (top < 6 ? source->head.height : lua_tointeger(L, 6));
	sx = (top < 7 ? 0 : lua_tointeger(L, 7));
	sy = (top < 8 ? 0 : lua_tointeger(L, 8));
	color = (top < 9 ? 0xFFFFFFFF : (uint32_t)lua_tointeger(L, 9));
	
	render_blit_img(dest->pixels, dest->head.width, dest->head.height, 
		dest->head.width,
		source, dx, dy, bw, bh, sx, sy, color);
	
	return 0;
}

// common functions
int icelua_fn_common_img_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "tga");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	img_t *img = lua_touserdata(L, -1);
	if(img == NULL)
		return 0;
	
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 3;
}

int icelua_fn_common_img_new(lua_State *L)
{
	int i;
	
	int top = icelua_assert_stack(L, 2, 2);
	
	int w = lua_tointeger(L, 1);
	int h = lua_tointeger(L, 2);
	
	if(w < 1 || h < 1)
		return luaL_error(L, "image too small");
	
	img_t *img = malloc(sizeof(img_t)+(w*h*sizeof(uint32_t)));
	if(img == NULL)
		return luaL_error(L, "could not allocate memory");
	
	img->head.idlen = 0; // no ID
	img->head.cmtype = 0; // no colourmap
	img->head.imgtype = 2; // uncompressed RGB
	img->head.cmoffs = 0;
	img->head.cmlen = 0;
	img->head.cmbpp = 0;
	img->head.xstart = 0;
	img->head.ystart = h-1;
	img->head.width = w;
	img->head.height = h;
	img->head.bpp = 32;
	img->head.flags = 0x20;
	
	for(i = 0; i < w*h; i++)
		img->pixels[i] = 0x00000000;
	
	img->udtype = UD_IMG;
	
	lua_pushlightuserdata(L, img);
	return 1;
}

int icelua_fn_common_img_pixel_set(lua_State *L)
{
	int i;
	
	int top = icelua_assert_stack(L, 4, 4);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);
	uint32_t color = lua_tointeger(L, 4);
	
	if(x < 0 || y < 0 || x >= img->head.width || y >= img->head.height)
		return 0;
	
	img->pixels[y*img->head.width+x] = color;
	
	return 0;
}

int icelua_fn_common_img_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	
	img_free(img);
	
	return 0;
}

int icelua_fn_common_img_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 2;
}
