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
//TODO
int icelua_fn_common_font_render_to_texture(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 3);
	
	TTF_Font *font = (TTF_Font *)lua_touserdata(L, 1);

	//font = TTF_OpenFont("pkg/base/ttf/propaganda.ttf", 16);
	// printf("POINTER INCOMING2");
	// printf(font);
	const char *text = lua_tostring(L, 2);
	
	uint32_t color = (top < 3 ? 0xFFFFFF : (uint32_t)lua_tointeger(L, 3));
	
	SDL_Color sdl_clr = {(color>>16)&255,(color>>8)&255,(color)&255, (color>>24)&255};
	
	SDL_Surface *font_rendered_surface = TTF_RenderText_Blended(font, text, sdl_clr);
	
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
	img_t *img = lua_touserdata(L, -1);
	
	int i;
	int iw = img->head.width;
	int ih = img->head.height;
	#ifndef DEDI
		expandtex_gl(&iw, &ih);
	#endif
	int x;
	int y;
	for (x=0; x<w; x++){
		for (y=0; y<h; y++){
			//int bpp = font_rendered_surface->format->BytesPerPixel; //=4
			/* Here p is the address to the pixel we want to set */
			uint32_t  *p = (Uint8 *)font_rendered_surface->pixels + y * font_rendered_surface->pitch + x * 4;
			
			img->pixels[y * iw +x]=*(uint32_t*)p;
		}		
	}
	return 1;
}

// common functions
int icelua_fn_common_font_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 2);
	
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");

	const uint32_t *ptsize = (top < 2 ? 16 : lua_tointeger(L, 2));
	if(ptsize == NULL)
		return luaL_error(L, "ptsize must be a natural number");	
		
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "ttf");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	int buf_size = 0;
	char *buf = lua_tolstring(L, -1, &buf_size);
	lua_remove(L, -1);

	SDL_RWops *src = SDL_RWFromMem(buf, buf_size+1);
	TTF_Font *font = TTF_OpenFontRW(src, 1, ptsize);
	// TTF_Font *font = TTF_OpenFont("pkg/base/ttf/propaganda.ttf", 16);//ptsize);
	// printf("POINTER INCOMING");
	// printf(font);
	if(font == NULL)
	{
		printf("\n%s\n", TTF_GetError());
		return luaL_error(L, "Font load error!");
	}
	
	lua_pushlightuserdata(L, font);
	return 1;
}

// TODO
// int icelua_fn_common_font_load_byindex(lua_State *L)
// {
// }
