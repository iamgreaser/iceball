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
#ifndef DEDI
void expandtex_gl(int *iw, int *ih);
#endif

// client functions
int icelua_fn_client_img_blit(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 10);
	int dx, dy, bw, bh, sx, sy;
	float scalex, scaley;
	uint32_t color;
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not an image");
	img_t *img = (img_t *)lua_touserdata(L, 1);
	if(img == NULL || (img->udtype != UD_IMG && img->udtype != UD_FBO))
		return luaL_error(L, "not an image");
	
	int width = (img->udtype == UD_FBO ? ((fbo_t *)img)->width : img->head.width);
	int height = (img->udtype == UD_FBO ? ((fbo_t *)img)->height : img->head.height);
	dx = lua_tointeger(L, 2);
	dy = lua_tointeger(L, 3);
	bw = (top < 4 ? width : lua_tointeger(L, 4));
	bh = (top < 5 ? height : lua_tointeger(L, 5));
	sx = (top < 6 ? 0 : lua_tointeger(L, 6));
	sy = (top < 7 ? 0 : lua_tointeger(L, 7));
	color = (top < 8 ? 0xFFFFFFFF : (uint32_t)lua_tointeger(L, 8));
	scalex = (top < 9 ? 1 : lua_tonumber(L, 9));
	scaley = (top < 10 ? 1 : lua_tonumber(L, 10));
	
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if(screen == NULL)
		return luaL_error(L, "cannot blit without a screen!");

	render_blit_img((uint32_t*)screen->pixels, screen->w, screen->h, screen->pitch/4,
		img, dx, dy, bw, bh, sx, sy, color, scalex, scaley);
#endif
	
	return 0;
}

int icelua_fn_client_img_blit_to(lua_State *L)
{
	int top = icelua_assert_stack(L, 4, 11);
	int dx, dy, bw, bh, sx, sy;
	float scalex, scaley;
	uint32_t color;
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "source not an image");
	if(lua_islightuserdata(L, 2) || !lua_isuserdata(L, 2))
		return luaL_error(L, "dest not an image");
	img_t *dest = (img_t *)lua_touserdata(L, 1);
	if(dest == NULL || dest->udtype != UD_IMG)
		return luaL_error(L, "source not an image");
	img_t *source = (img_t *)lua_touserdata(L, 2);
	if(source == NULL || source->udtype != UD_IMG)
		return luaL_error(L, "dest not an image");
	
	dx = lua_tointeger(L, 3);
	dy = lua_tointeger(L, 4);
	bw = (top < 5 ? source->head.width : lua_tointeger(L, 5));
	bh = (top < 6 ? source->head.height : lua_tointeger(L, 6));
	sx = (top < 7 ? 0 : lua_tointeger(L, 7));
	sy = (top < 8 ? 0 : lua_tointeger(L, 8));
	color = (top < 9 ? 0xFFFFFFFF : (uint32_t)lua_tointeger(L, 9));
	scalex = (top < 10 ? 1 : lua_tonumber(L, 10));
	scaley = (top < 11 ? 1 : lua_tonumber(L, 11));
	
#ifdef DEDI
	return luaL_error(L, "lm: why the hell is this being called in the dedi version?");
#else
	render_blit_img(dest->pixels, dest->head.width, dest->head.height, 
		dest->head.width,
		source, dx, dy, bw, bh, sx, sy, color, scalex, scaley);
#endif

#ifndef DEDI
	dest->tex_dirty = 1;
#endif
	
	return 0;
}

// common functions
int icelua_fn_common_img_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 2);
	
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");

	const char *fmt = (top < 2 ? "tga" : lua_tostring(L, 2));
	if(fmt == NULL)
		return luaL_error(L, "format must be a string");
	
	if(strcmp(fmt, "tga") && strcmp(fmt, "png")) // && strcmp(fmt, "auto"))
		return luaL_error(L, "invalid format for img_load");
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, fmt);
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	img_t *img = (img_t *)lua_touserdata(L, -1);
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
	int iw = w;
	int ih = h;
#ifndef DEDI
	expandtex_gl(&iw, &ih);
#endif
	
	if(w < 1 || h < 1)
		return luaL_error(L, "image too small");
	
	//img_t *img = (img_t*)malloc(sizeof(img_t)+(iw*ih*sizeof(uint32_t)));
	img_t *img = (img_t*)lua_newuserdata(L, sizeof(img_t)+(iw*ih*sizeof(uint32_t)));
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
	
	for(i = 0; i < iw*ih; i++)
		img->pixels[i] = 0x00000000;
	
	img->udtype = UD_IMG;
#ifndef DEDI
	img->tex = 0;
	img->tex_dirty = 1;
#endif
	
	//*(img_t **)lua_newuserdata(L, sizeof(void *)) = img;
	img_gc_set(L);
	return 1;
}

int icelua_fn_common_img_pixel_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 4, 4);
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not an image");
	img_t *img = (img_t *)lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);
	uint32_t color = lua_tointeger(L, 4);
	
	if(x < 0 || y < 0 || x >= img->head.width || y >= img->head.height)
		return 0;

	int iw = img->head.width;
	int ih = img->head.height;
#ifndef DEDI
	expandtex_gl(&iw, &ih);
#endif
	
	img->pixels[y*iw+x] = color;
#ifndef DEDI
	img->tex_dirty = 1;
#endif
	
	return 0;
}


int icelua_fn_common_img_pixel_get(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not an image");
	img_t *img = (img_t *)lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	int x = lua_tointeger(L, 2);
	int y = lua_tointeger(L, 3);
	
	if(x < 0 || y < 0 || x >= img->head.width || y >= img->head.height)
		return 0;

	int iw = img->head.width;
	int ih = img->head.height;
#ifndef DEDI
	expandtex_gl(&iw, &ih);
#endif
	
	lua_pushnumber(L, (double)(uint32_t)img->pixels[y*iw+x]);
	return 1;
}


int icelua_fn_common_img_fill(lua_State *L)
{
	int i;
	
	int top = icelua_assert_stack(L, 2, 2);
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not an image");
	img_t *img = (img_t *)lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	uint32_t color = lua_tointeger(L, 2);
	
	int iw = img->head.width;
	int ih = img->head.height;
#ifndef DEDI
	expandtex_gl(&iw, &ih);
#endif
	for (i=0; i<(iw*ih); i++)
		img->pixels[i] = color;    
	
#ifndef DEDI
	img->tex_dirty = 1;
#endif
	
	return 0;
}

int icelua_fn_common_img_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not an image");
	img_t *img = (img_t *)lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	
#ifdef ALLOW_EXPLICIT_FREE
	// Nope
	//img_free(img);
#endif
	
	return 0;
}

int icelua_fn_common_img_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not an image");
	img_t *img = (img_t *)lua_touserdata(L, 1);
	if(img == NULL || img->udtype != UD_IMG)
		return luaL_error(L, "not an image");
	
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 2;
}

