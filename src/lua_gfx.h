
// client functions
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
int icelua_fn_client_gfx_alpha_test(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	int enabled = lua_toboolean(L, 1);
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if(enabled) glEnable(GL_ALPHA_TEST);
	else glDisable(GL_ALPHA_TEST);
#endif
	return 0;
}

int icelua_fn_client_gfx_depth_mask(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	int enabled = lua_toboolean(L, 1);
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	glDepthMask(enabled ? GL_TRUE : GL_FALSE);
#endif
	return 0;
}

int icelua_fn_client_gfx_depth_test(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	int enabled = lua_toboolean(L, 1);
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if(enabled) glEnable(GL_DEPTH_TEST);
	else glDisable(GL_DEPTH_TEST);
#endif
	return 0;
}

int icelua_fn_client_gfx_clear_depth(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	glClear(GL_DEPTH_BUFFER_BIT);
#endif
	return 0;
}

int icelua_fn_client_gfx_stencil_test(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	int enabled = lua_toboolean(L, 1);
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if(enabled) glEnable(GL_STENCIL_TEST);
	else glDisable(GL_STENCIL_TEST);
#endif
	return 0;
}

int icelua_fn_client_gfx_stencil_op(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	int i;

	const char *mask = lua_tostring(L, 1);
	if(mask == NULL || strlen(mask) != 3)
		return luaL_error(L, "gfx_stencil_op requires a 3-char string");

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	GLenum a[3];
	for(i = 0; i < 3; i++)
	switch(mask[i])
	{
		case ';': a[i] = GL_KEEP; break;
		case '0': a[i] = GL_ZERO; break;
		case '=': a[i] = GL_REPLACE; break;
		case '+': a[i] = GL_INCR; break;
		case '-': a[i] = GL_DECR; break;
		case '~': a[i] = GL_INVERT; break;
		default:
			return luaL_error(L, "invalid char '%c' in stencil op string", mask[i]);
	}

	glStencilOp(a[0], a[1], a[2]);
#endif

	return 0;
}

int icelua_fn_client_gfx_stencil_func(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);

	const char *func = lua_tostring(L, 1);
	int ref = lua_tointeger(L, 2);
	int mask = lua_tointeger(L, 3);
	if(func == NULL)
		return luaL_error(L, "gfx_stencil_op requires a string for func");

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	GLenum rfunc = GL_KEEP;
	if(0) rfunc = GL_KEEP;
	else if(!strcmp(func, "0")) rfunc = GL_NEVER;
	else if(!strcmp(func, "<")) rfunc = GL_LESS;
	else if(!strcmp(func, "<=")) rfunc = GL_LEQUAL;
	else if(!strcmp(func, ">")) rfunc = GL_GREATER;
	else if(!strcmp(func, ">=")) rfunc = GL_GEQUAL;
	else if(!strcmp(func, "==")) rfunc = GL_EQUAL;
	else if(!strcmp(func, "~=")) rfunc = GL_NOTEQUAL;
	else if(!strcmp(func, "1")) rfunc = GL_ALWAYS;
	else
		return luaL_error(L, "invalid stencil func \"%s\"", func);

	glStencilFunc(rfunc, ref, mask);
#endif

	return 0;
}

int icelua_fn_client_gfx_tex_available(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);

#ifndef DEDI
	lua_pushinteger(L, (gl_max_texunits > VA_MAX_IMG
		? VA_MAX_IMG
		: gl_max_texunits));
	return 1;
#else
	return 0;
#endif
}


