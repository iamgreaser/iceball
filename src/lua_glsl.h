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

int shader_gc_lua(lua_State *L)
{
	shader_t *shader = lua_touserdata(L, 1);
	if(shader != NULL)
	{
		printf("Freeing shader @ %p\n", shader);

#ifndef DEDI
		if(shader->prog != 0)
			glDeleteProgram(shader->prog);
#endif
	}

	return 0;
}

int icelua_fn_client_gfx_glsl_available(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	// we could possibly be a bit more accurate with this?
	if(gl_shaders && (GL_VERSION_2_1))
		lua_pushstring(L, "2.1");
	else if(gl_shaders && (GL_VERSION_2_0))
		lua_pushstring(L, "2.0");
	else
		lua_pushnil(L);

	return 1;
#endif
}

int icelua_fn_client_glsl_create(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 3);
	int i;
	int len;

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	GLint success = GL_FALSE;
	GLuint prog;

	if(!gl_shaders)
		return luaL_error(L, "shaders disabled in config!");
	if(!(GL_VERSION_2_0))
		return luaL_error(L, "shaders not supported on your GPU!");

	const char *srcv = lua_tostring(L, 1);
	const char *srcf = lua_tostring(L, 2);

	if(top >= 3 && !lua_istable(L, 3))
		return luaL_error(L, "expected list for attr_array");

	luaL_Buffer b;

	// Set up buffer
	luaL_buffinit(L, &b);

	// Create shader program
	GLuint sh_v = glCreateShader(GL_VERTEX_SHADER);
	GLuint sh_f = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(sh_v, 1, &srcv, NULL);
	glShaderSource(sh_f, 1, &srcf, NULL);
	glCompileShader(sh_v);

	glGetShaderiv(sh_v, GL_INFO_LOG_LENGTH, &len);
	if (len > 0) {
		char info[len];
		glGetShaderInfoLog(sh_v, len, NULL, info);
		luaL_addstring(&b, "Vertex shader compile error:\n");
		luaL_addstring(&b, info);
		luaL_addstring(&b, "\n");
	}
	glCompileShader(sh_f);

	glGetShaderiv(sh_f, GL_INFO_LOG_LENGTH, &len);
	if (len > 0) {
		char info[len];
		glGetShaderInfoLog(sh_f, len, NULL, info);
		luaL_addstring(&b, "Fragment shader compile error:\n");
		luaL_addstring(&b, info);
		luaL_addstring(&b, "\n");
	}
	prog = glCreateProgram();
	glAttachShader(prog, sh_v);
	glAttachShader(prog, sh_f);

	if(top >= 3)
	{
		len = lua_objlen(L, 3);
		for(i = 0; i < len; i++)
		{
			lua_pushinteger(L, i+1);
			lua_gettable(L, 3);
			const char *name = lua_tostring(L, -1);
			lua_pop(L, 1);
			if(name != NULL)
				glBindAttribLocation(prog, i+1, name);
		}

	}

	glLinkProgram(prog);

	glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &len);
	if (len > 0) {
		char info[len];
		glGetProgramInfoLog(prog, len, NULL, info);
		luaL_addstring(&b, "Link error:\n");
		luaL_addstring(&b, info);
		luaL_addstring(&b, "\n");
	}

	if(sh_v != 0) glDeleteShader(sh_v);
	if(sh_f != 0) glDeleteShader(sh_f);

	// Push result string
	luaL_pushresult(&b);

	// Create userdata if practical
	glGetProgramiv(prog, GL_LINK_STATUS, &success);
	if(success == GL_TRUE)
	{
		shader_t *shader = lua_newuserdata(L, sizeof(shader_t));
		shader->udtype = UD_SHADER;
		shader->prog = prog;
		lua_newtable(L);
		lua_pushcfunction(L, shader_gc_lua);
		lua_setfield(L, -2, "__gc");
		lua_setmetatable(L, -2);
	} else {
		if(prog != 0) glDeleteProgram(prog);
		lua_pushnil(L);
	}

	// Swap stack around
	lua_pushvalue(L, -2);
	lua_remove(L, -3);


	// Return!
	return 2;
#endif
}

int icelua_fn_client_glsl_use(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	
	if(!gl_shaders)
		return luaL_error(L, "shaders disabled in config!");
	if(!(GL_VERSION_2_0))
		return luaL_error(L, "shaders not supported on your GPU!");

	if(lua_isnil(L, 1))
	{
		glUseProgram(0);
	} else {
		shader_t *shader = lua_touserdata(L, 1);

		if(shader == NULL || shader->udtype != UD_SHADER)
			return luaL_error(L, "not a valid shader");

		glUseProgram(shader->prog);
	}

	return 0;
#endif
}

int icelua_fn_client_glsl_get_uniform_loc(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	
	if(!gl_shaders)
		return luaL_error(L, "shaders disabled in config!");
	if(!(GL_VERSION_2_0))
		return luaL_error(L, "shaders not supported on your GPU!");

	shader_t *shader = lua_touserdata(L, 1);
	if(shader == NULL || shader->udtype != UD_SHADER)
		return luaL_error(L, "not a valid shader");
	const char *name = lua_tostring(L, 2);
	if(name == NULL)
		return luaL_error(L, "expected a string for name");

	int result = glGetUniformLocation(shader->prog, name);
	if(result == -1)
		lua_pushnil(L);
	else
		lua_pushnumber(L, (double)result);

	return 1;
#endif
}

int icelua_fn_client_glsl_set_uniform_f(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 5);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	
	if(!gl_shaders)
		return luaL_error(L, "shaders disabled in config!");
	if(!(GL_VERSION_2_0))
		return luaL_error(L, "shaders not supported on your GPU!");

	// Fail silently if nil
	// It's nicer that way if you have several shaders that don't take all the same uniforms
	// If you needed this shader you would have complained after glsl_create
	// If you needed this uniform you would have complained after glsl_get_uniform_loc
	if(lua_isnil(L, 1))
		return 0;

	GLuint idx = lua_tointeger(L, 1);

	if(top == 2)
		glUniform1f(idx,
			lua_tonumber(L, 2));
	else if(top == 3)
		glUniform2f(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3));
	else if(top == 4)
		glUniform3f(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3),
			lua_tonumber(L, 4));
	else
		glUniform4f(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3),
			lua_tonumber(L, 4),
			lua_tonumber(L, 5));

	return 0;
#endif
}

int icelua_fn_client_glsl_set_uniform_i(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 5);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	
	if(!gl_shaders)
		return luaL_error(L, "shaders disabled in config!");
	if(!(GL_VERSION_2_0))
		return luaL_error(L, "shaders not supported on your GPU!");

	// Fail silently if nil
	// It's nicer that way if you have several shaders that don't take all the same uniforms
	// If you needed this shader you would have complained after glsl_create
	// If you needed this uniform you would have complained after glsl_get_uniform_loc
	if(lua_isnil(L, 1))
		return 0;

	GLuint idx = lua_tointeger(L, 1);

	if(top == 2)
		glUniform1i(idx,
			lua_tonumber(L, 2));
	else if(top == 3)
		glUniform2i(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3));
	else if(top == 4)
		glUniform3i(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3),
			lua_tonumber(L, 4));
	else
		glUniform4i(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3),
			lua_tonumber(L, 4),
			lua_tonumber(L, 5));

	return 0;
#endif
}

int icelua_fn_client_glsl_set_uniform_ui(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 5);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	
	if(!gl_shaders)
		return luaL_error(L, "shaders disabled in config!");
	if(!(GL_VERSION_2_0))
		return luaL_error(L, "shaders not supported on your GPU!");

	// Fail silently if nil
	// It's nicer that way if you have several shaders that don't take all the same uniforms
	// If you needed this shader you would have complained after glsl_create
	// If you needed this uniform you would have complained after glsl_get_uniform_loc
	if(lua_isnil(L, 1))
		return 0;

	GLuint idx = lua_tointeger(L, 1);

	if(top == 2)
		glUniform1ui(idx,
			lua_tonumber(L, 2));
	else if(top == 3)
		glUniform2ui(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3));
	else if(top == 4)
		glUniform3ui(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3),
			lua_tonumber(L, 4));
	else
		glUniform4ui(idx,
			lua_tonumber(L, 2),
			lua_tonumber(L, 3),
			lua_tonumber(L, 4),
			lua_tonumber(L, 5));

	return 0;
#endif
}


