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

int va_gc_lua(lua_State *L)
{
	va_t *va = (va_t *)lua_touserdata(L, 1);
	//printf("collect va %p\n", va);

	if(va != NULL)
	{
#ifndef DEDI
		if(va->vbo != 0)
			glDeleteBuffers(1, &(va->vbo));
#endif
		if(va->data != NULL)
			free(va->data);
	}

	return 0;
}

// client functions
int icelua_fn_client_va_render_global(lua_State *L)
{
	int top = icelua_assert_stack(L, 8, 11);
	int i;
	float px, py, pz;
	float ry, rx, ry2;
	float scale;
	float alpha;

	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not a VA");
	va_t *va = (va_t*)lua_touserdata(L, 1);
	if(va == NULL || va->udtype != UD_VA)
		return luaL_error(L, "not a VA");

	img_t *img[VA_MAX_IMG];
	int img_count = 1;
	if(top >= 9 && lua_istable(L, 9))
	{
		img_count = lua_objlen(L, 9);

		for(i = 0; i < img_count; i++)
		{
			lua_pushnumber(L, i+1);
			lua_gettable(L, 9);
			img[i] = (!lua_isnil(L, -1)
				? (img_t *)lua_touserdata(L, -1)
				: NULL);
			lua_pop(L, 1);
		}
	} else {
		img[0] = (top >= 9 && !lua_isnil(L, 9)
			? (img_t *)lua_touserdata(L, 9)
			: NULL);
	}
	for(i = 0; i < img_count; i++)
		if(img[i] != NULL && img[i]->udtype != UD_IMG && img[i]->udtype != UD_FBO)
			return luaL_error(L, "texture %d not an image", i+1);

	px = lua_tonumber(L, 2);
	py = lua_tonumber(L, 3);
	pz = lua_tonumber(L, 4);

	ry = lua_tonumber(L, 5);
	rx = lua_tonumber(L, 6);
	ry2 = lua_tonumber(L, 7);

	scale = lua_tonumber(L, 8);
	alpha = (top >= 11 && lua_isnumber(L, 11) ? lua_tonumber(L, 11) : 1.0f);

	const char *bmode = (top >= 10 ? lua_tostring(L, 10) : NULL);
	char sfactor = '1', dfactor = '0';
	if(bmode != NULL && strlen(bmode) >= 2)
	{
		sfactor = bmode[0];
		dfactor = bmode[1];
	}

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	render_vertex_array((uint32_t*)NULL, screen_width, screen_height, 0/4, &tcam,
		va, 0, px, py, pz, ry, rx, ry2, scale, img, (bmode != NULL), sfactor, dfactor, alpha,
		img_count);
#endif

	return 0;
}

int icelua_fn_client_va_render_local(lua_State *L)
{
	int top = icelua_assert_stack(L, 8, 11);
	int i;
	float px, py, pz;
	float ry, rx, ry2;
	float scale;
	float alpha;

	if(lua_islightuserdata(L, 1) || !lua_isuserdata(L, 1))
		return luaL_error(L, "not a VA");
	va_t *va = (va_t*)lua_touserdata(L, 1);
	if(va == NULL || va->udtype != UD_VA)
		return luaL_error(L, "not a VA");

	img_t *img[VA_MAX_IMG];
	int img_count = 1;
	if(top >= 9 && lua_istable(L, 9))
	{
		img_count = lua_objlen(L, 9);

		for(i = 0; i < img_count; i++)
		{
			lua_pushnumber(L, i+1);
			lua_gettable(L, 9);
			img[i] = (!lua_isnil(L, -1)
				? (img_t *)lua_touserdata(L, -1)
				: NULL);
			lua_pop(L, 1);
		}
	} else {
		img[0] = (top >= 9 && !lua_isnil(L, 9)
			? (img_t *)lua_touserdata(L, 9)
			: NULL);
	}
	for(i = 0; i < img_count; i++)
		if(img[i] != NULL && img[i]->udtype != UD_IMG && img[i]->udtype != UD_FBO)
			return luaL_error(L, "texture %d not an image", i+1);


	px = lua_tonumber(L, 2);
	py = lua_tonumber(L, 3);
	pz = lua_tonumber(L, 4);

	ry = lua_tonumber(L, 5);
	rx = lua_tonumber(L, 6);
	ry2 = lua_tonumber(L, 7);

	scale = lua_tonumber(L, 8);
	alpha = (top >= 11 && lua_isnumber(L, 11) ? lua_tonumber(L, 11) : 1.0f);

	const char *bmode = (top >= 10 ? lua_tostring(L, 10) : NULL);
	char sfactor = '1', dfactor = '0';
	if(bmode != NULL && strlen(bmode) >= 2)
	{
		sfactor = bmode[0];
		dfactor = bmode[1];
	}

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	render_vertex_array((uint32_t*)NULL, screen_width, screen_height, 0/4, &tcam,
		va, 1, px, py, pz, ry, rx, ry2, scale, img, (bmode != NULL), sfactor, dfactor, alpha,
		img_count);
#endif

	return 0;
}

int icelua_fn_common_va_make(lua_State *L)
{
	int i, j;
	int top = icelua_assert_stack(L, 1, 3);

	if(!lua_istable(L, 1))
		return luaL_error(L, "arg 1 not a table");
	if(top >= 2 && (!lua_isnil(L, 2)) && (lua_islightuserdata(L, 2) || !lua_isuserdata(L, 2)))
		return luaL_error(L, "arg 2 not a VA");

	// Get length
	int data_len = lua_objlen(L, 1);

	// Create VA
	va_t *va;
	if(top >= 2 && (!lua_isnil(L, 2)))
	{
		va = lua_touserdata(L, 2);
		lua_pushvalue(L, 2);
	} else {
		va = (va_t *)lua_newuserdata(L, sizeof(va_t));
		va->udtype = UD_VA;
		va->data_len = 0;
		va->data = NULL;
#ifndef DEDI
		va->vbo = 0;
		va->vbo_dirty = 1;
#endif
		// Set GC
		lua_newtable(L);
		lua_pushcfunction(L, va_gc_lua);
		lua_setfield(L, -2, "__gc");
		lua_setmetatable(L, -2);
	}

	if(va == NULL || va->udtype != UD_VA)
		return luaL_error(L, "arg 2 not a VA");

	const char *vafmt = (top >= 3 ? lua_tostring(L, 3) : "3v,3c");

	// Get VA format
	if(vafmt == NULL)
		return luaL_error(L, "arg 3 not a string");

	// Set defaults
	va->vertex_offs = -1;
	va->color_offs = -1;
	va->normal_offs = -1;
	va->texcoord_offs[0] = -1;
	va->texcoord_count = 0;
	va->attr_offs[0] = -1;
	va->attr_count = 0;
	va->stride = 0;

	// Parse string properly
	const char *fol = vafmt;
	while(fol[0] != '\x00')
	{
		if(fol[0] >= '1' && fol[0] <= '4' && fol[1] != '\x00')
		switch(fol[1])
		{
			case 'v':
				// Vertex
				if(fol[0] < '2' || fol[0] > '4')
					return luaL_error(L, "VA format not supported");
				if(va->vertex_offs != -1)
					return luaL_error(L, "VA format not supported");
				va->vertex_offs = va->stride;
				va->vertex_size = fol[0] - '1' + 1;
				va->stride += va->vertex_size;
				break;

			case 'c':
				// Colour
				if(fol[0] < '3' || fol[0] > '4')
					return luaL_error(L, "VA format not supported");
				if(va->color_offs != -1)
					return luaL_error(L, "VA format not supported");
				va->color_offs = va->stride;
				va->color_size = fol[0] - '1' + 1;
				va->stride += va->color_size;
				break;

			case 'n':
				// Normal
				if(fol[0] < '3' || fol[0] > '3')
					return luaL_error(L, "VA format not supported");
				if(va->normal_offs != -1)
					return luaL_error(L, "VA format not supported");
				va->normal_offs = va->stride;
				va->stride += 3;
				break;

			case 't':
				// Texcoord
				if(fol[0] < '1' || fol[0] > '4')
					return luaL_error(L, "VA format not supported");
				if(va->texcoord_count >= VA_MAX_TC)
					return luaL_error(L, "VA format not supported");
				va->texcoord_offs[va->texcoord_count] = va->stride;
				va->texcoord_size[va->texcoord_count] = fol[0] - '1' + 1;
				va->stride += va->texcoord_size[va->texcoord_count];
				va->texcoord_count++;
				break;

			case 'a':
				// Attribute
				if(fol[0] < '1' || fol[0] > '4')
					return luaL_error(L, "VA format not supported");
				if(va->texcoord_count >= VA_MAX_ATTR)
					return luaL_error(L, "VA format not supported");
				va->attr_offs[va->attr_count] = va->stride;
				va->attr_size[va->attr_count] = fol[0] - '1' + 1;
				va->stride += va->attr_size[va->attr_count];
				va->attr_count++;
				break;
		}

		fol += 2;
		if(fol[0] == ',')
			fol += 1;
		else if(fol[0] != '\x00')
			return luaL_error(L, "VA format not supported");
	}

	if(va->vertex_offs == -1)
		return luaL_error(L, "VA format not supported");

	va->data_len = data_len;
	va->data = realloc(va->data, sizeof(float)*va->stride*va->data_len);

	// Fill VA
	for(i = 0; i < data_len; i++)
	{
		lua_pushinteger(L, i+1);
		lua_gettable(L, 1);

		for(j = 0; j < va->stride; j++)
		{
			lua_pushinteger(L, j+1);
			lua_gettable(L, -2);
			va->data[i*va->stride + j] = lua_tonumber(L, -1);
			lua_pop(L, 1);
		}

		lua_pop(L, 1);
	}

#ifndef DEDI
	// Mark VBO dirty
	va->vbo_dirty = 1;
#endif

	return 1;
}


