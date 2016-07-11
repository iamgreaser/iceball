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

int icelua_fn_client_font_ttf_gc(lua_State *L)
{
	font_t *fnt = lua_touserdata(L, 1);
	if(fnt != NULL)
	{
		printf("Freeing font @ %p\n", fnt);

		font_free(fnt);
	}

}

int icelua_fn_client_font_ttf_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	//const char *fname = lua_tostring(L, 1);

	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "ttf");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
/*
	font_t *fnt = lua_newuserdata(L, sizeof(font_t));
	if (!font_load_ttf(fnt, fname)) {
		lua_pushnil(L);
	}
*/
	return 1;
}

int icelua_fn_client_font_ttf_draw(lua_State *L)
{
	int top = icelua_assert_stack(L, 6, 6);

	font_t *fnt = lua_touserdata(L, 1);
	float x = lua_tonumber(L, 2);
	float y = lua_tonumber(L, 3);
	int size = lua_tointeger(L, 4);
	const char *str = lua_tostring(L, 5);
	uint32_t color = lua_tointeger(L, 6);

	float width = font_draw(fnt, x, y, size, color, str);
	lua_pushnumber(L, width);

	return 1;
}

int icelua_fn_client_font_ttf_flush(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	font_t *fnt = lua_touserdata(L, 1);
	font_flush(fnt);

	return 0;
}

int icelua_fn_client_font_ttf_lineheight(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);

	font_t *fnt = lua_touserdata(L, 1);
	int size = lua_tointeger(L, 2);

	lua_pushnumber(L, fnt->line_height * size);
	return 1;
}

int icelua_fn_client_font_ttf_draw_glyph(lua_State *L)
{
	int top = icelua_assert_stack(L, 6, 7);

	font_t *fnt = lua_touserdata(L, 1);
	float x = lua_tonumber(L, 2);
	float y = lua_tonumber(L, 3);
	int size = lua_tointeger(L, 4);
	uint32_t codepoint = lua_tointeger(L, 5);
	uint32_t color = lua_tointeger(L, 6);

	font_glyph_t glyph;

	int idx = font_get_glyph(fnt, codepoint, size, &glyph);
	if (idx != -1) {
		float kerning = 0;

		if (top > 5) {
			int pidx = lua_tointeger(L, 7);

			if (pidx >= 0) {
#ifdef USE_FREETYPE

#else
				float scale = stbtt_ScaleForPixelHeight(&fnt->info, (float)size);
				kerning = scale * stbtt_GetGlyphKernAdvance(&fnt->info, fnt->glyphs[pidx].glyph_idx, glyph.glyph_idx);
#endif
			}
		}

		font_draw_glyph(fnt,
			x + glyph.x_offset,
			y - glyph.y_offset + (fnt->ascent + fnt->descent) * size,
			color,
			glyph);

		lua_pushnumber(L, glyph.x_advance + kerning);
		lua_pushinteger(L, glyph.height);
		lua_pushinteger(L, idx);
	} else {
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, -1);
	}

	return 3;
}
