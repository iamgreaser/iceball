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
	int top = icelua_assert_stack(L, 1, 2);
	
	TTF_Font *font = lua_touserdata(L, 1);
	
	const char *text = lua_tostring(L, 2);
	
	uint32_t color = (top < 3 ? "0xFFFFFFFF" : (uint32_t)lua_tointeger(L, 3));
	
	SDL_Color sdl_clr = {(color>>16)&255,(color>>8)&255,(color)&255};
	
	SDL_Surface *font_rendered_surface = TTF_RenderText_Solid(font, text, sdl_clr);
	
	lua_pushlightuserdata(L, font_rendered_surface);
	return 1;
}

// common functions
int icelua_fn_common_font_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 2);
	
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");

	const uint32_t *ptsize = (top < 2 ? "16" : lua_tostring(L, 2));
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
	
	SDL_RWops *src = SDL_RWFromMem(buf, buf_size);
	TTF_Font *font = TTF_OpenFontRW(src, 1, ptsize);
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