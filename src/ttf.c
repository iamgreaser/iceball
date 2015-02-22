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

#include "common.h"

img_t *font_ttf_render_to_texture(TTF_Font *font, const char *text, uint32_t color, lua_State *L)
{
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
	img_t *img = (img_t *)lua_touserdata(L, -1);

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
			uint32_t  *p = (Uint8 *)font_rendered_surface->pixels + y * font_rendered_surface->pitch + x * 4;

			img->pixels[y * iw +x]=*(uint32_t*)p;
		}
	}
	SDL_FreeSurface(font_rendered_surface);

	//aand get if off the stack again, because pointers
	img = (img_t *)lua_touserdata(L, -1);
	return img;
}
