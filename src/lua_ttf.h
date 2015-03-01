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
int icelua_fn_client_font_render_to_texture(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 5);

	img_t *img;

	const char *text = lua_tostring(L, 2);
	if(text == NULL || text[0] == '\x00')
	{
		lua_getglobal(L, "common");
		lua_getfield(L, -1, "img_new");
		lua_remove(L, -2);
		lua_pushnumber(L, 2); //2x2 transparent image
		lua_pushnumber(L, 2);
		lua_call(L, 2, 1);
		//loads the return of the function - an empty image onto the stack
		//since it's on top of the stack the return value will be it so we can work it
		img = (img_t *)lua_touserdata(L, -1);
		return 1;
	}

	TTF_Font *font = (TTF_Font *)lua_touserdata(L, 1);
	if (font == NULL) //this is considered normal behaviour in case of fetching
	{
		lua_getglobal(L, "common");
		lua_getfield(L, -1, "img_new");
		lua_remove(L, -2);
		lua_pushnumber(L, 2); //2x2 transparent image
		lua_pushnumber(L, 2);
		lua_call(L, 2, 1);
		//loads the return of the function - an empty image onto the stack
		//since it's on top of the stack the return value will be it so we can work it
		img = (img_t *)lua_touserdata(L, -1);
		return 1;
	}

	uint32_t color = (top < 3 ? 0xFFFFFF : (uint32_t)lua_tointeger(L, 3));

	if (top == 4 || top == 5)
	{
		uint32_t shadow_color = (uint32_t)lua_tointeger(L, 4);

		uint32_t shadow_size = (top < 5 ? 1 : (uint32_t)lua_tointeger(L, 5));

		TTF_SetFontOutline(font, shadow_size);
		color = shadow_color;
	}

	SDL_Color text_sdl_clr = {(color>>16)&255,(color>>8)&255,(color)&255,255};

	SDL_Surface *font_rendered_surface = TTF_RenderText_Blended(font, text, text_sdl_clr);

	if(font_rendered_surface == NULL)
	{
		printf("TTF render error: %s\n", TTF_GetError());
		lua_getglobal(L, "common");
		lua_getfield(L, -1, "img_new");
		lua_remove(L, -2);
		lua_pushnumber(L, 2); //2x2 transparent image
		lua_pushnumber(L, 2);
		lua_call(L, 2, 1);

		img = (img_t *)lua_touserdata(L, -1);
		printf("Warning: Recovered from TTF render error, no text rendered!\n");
		return 1;
	}

	int w = font_rendered_surface->w;
	int h = font_rendered_surface->h;
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "img_new");
	lua_remove(L, -2);
	lua_pushnumber(L, w);
	lua_pushnumber(L, h);
	lua_call(L, 2, 1);
	//loads the return of the function - an empty image onto the stack
	//since it's on top of the stack the return value will be it so we can work it
	img = (img_t *)lua_touserdata(L, -1);

	int iw = img->head.width;
	int ih = img->head.height;
	#ifndef DEDI
		expandtex_gl(&iw, &ih);
	#endif
	int x;
	int y;
	for (x=0; x<w; x++){
		for (y=0; y<h; y++){
			//int bpp = font_rendered_surface->format->BytesPerPixel; //always 4 in our case
			//but just for reference ^
			uint32_t *p = (uint32_t *)((Uint8 *)font_rendered_surface->pixels + y * font_rendered_surface->pitch + x * sizeof(uint32_t));

			img->pixels[y*iw + x] = *p;
		}
	}
	if (top == 4 || top == 5)
	{
		TTF_SetFontOutline(font, 0);
	}

	//aand get if off the stack again, because pointers
	img = (img_t *)lua_touserdata(L, -1);
	lua_pushnumber(L, w);
	lua_pushnumber(L, h);
	return 3;
}

// common functions
int icelua_fn_common_font_ttf_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 4);

	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");

	const uint32_t ptsize = (top < 2 ? 16 : lua_tointeger(L, 2));
	if(ptsize == 0)
		return luaL_error(L, "ptsize must be a natural number");

	const uint32_t font_index = (top < 3 ? 0 : lua_tointeger(L, 3));
	const uint32_t font_israw = (top < 4 ? 0 : lua_toboolean(L, 4));

	const char *buf = NULL;
	size_t buf_size = 0;
	if(font_israw)
	{
		buf = lua_tolstring(L, 1, &buf_size);
	} else {
		lua_getglobal(L, "common");
		lua_getfield(L, -1, "fetch_block");
		lua_remove(L, -2);
		lua_pushstring(L, "ttf");
		lua_pushvalue(L, 1);
		lua_call(L, 2, 1);

		buf = lua_tolstring(L, -1, &buf_size);
	}

	if(buf == NULL)
		return luaL_error(L, "ttf_load failed to get TTF data");

	SDL_RWops *src = SDL_RWFromConstMem(buf, buf_size);
	TTF_Font *font = TTF_OpenFontIndexRW(src, 1, ptsize, font_index);
	lua_remove(L, -1);

	if(font == NULL)
	{
		printf("TTF error: %s\n", TTF_GetError());
		return luaL_error(L, "Font load error!");
	}

	lua_pushlightuserdata(L, font);
	return 1;
}

int icelua_fn_common_font_get_height(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	TTF_Font *font = (TTF_Font *)lua_touserdata(L, 1);

	if(font == NULL)
	{
		printf("TTF get height font error: %s\n", TTF_GetError());
		return 0;
	}

	int height = TTF_FontHeight(font);

	lua_pushnumber(L, height);
	return 1;
}

int icelua_fn_common_font_get_size(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	TTF_Font *font = (TTF_Font *)lua_touserdata(L, 1);

	if(font == NULL)
	{
		printf("TTF get font size error: %s\n", TTF_GetError());
		return 0;
	}

	const char *text = lua_tostring(L, 2);

	int w,h;
	if(TTF_SizeUNICODE(font,text,&w,&h) == 0) {
		lua_pushnumber(L, w);
		lua_pushnumber(L, h);
	}
	return 1;
}
