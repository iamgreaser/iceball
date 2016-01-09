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

int fbo_gc_lua(lua_State *L)
{
	fbo_t *fbo = lua_touserdata(L, 1);
	if(fbo != NULL)
	{
		printf("Freeing fbo @ %p\n", fbo);

#ifndef DEDI
		if(fbo->ctex != 0)
			glDeleteTextures(1, &(fbo->ctex));
		if(fbo->dstex != 0)
			glDeleteTextures(1, &(fbo->dstex));
		if(fbo->handle != 0)
			glDeleteFramebuffers(1, &(fbo->handle));
#endif
	}

	return 0;
}

int icelua_fn_client_gfx_fbo_available(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	// XXX: We will only cover the EXT version if someone needs it.
	// I suspect GLEW ends up wrapping it to the ARB version anyway.

	lua_pushboolean(L, gl_use_fbo && (GLAD_GL_ARB_framebuffer_object));

	return 1;
#endif
}

int icelua_fn_client_fbo_create(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	int w = lua_tointeger(L, 1);
	int h = lua_tointeger(L, 2);
	int use_stencil = lua_toboolean(L, 3);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if(!gl_use_fbo)
		return luaL_error(L, "FBOs not enabled!");
	if(!(GLAD_GL_ARB_framebuffer_object))
		return luaL_error(L, "FBOs not supported by this GPU!");

	// Generate object handles
	GLuint handle;
	GLuint ctex, dstex;
	glGenTextures(1, &ctex);
	glGenTextures(1, &dstex);
	glGenFramebuffers(1, &handle);

	// Create FBO and textures
	glBindFramebuffer(GL_FRAMEBUFFER, handle);
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, ctex);
	glGetError();
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glFinish();
	int err_ctex = glGetError();
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, ctex, 0);
	glBindTexture(GL_TEXTURE_2D, dstex);
	glGetError();
	if(use_stencil)
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, w, h, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, NULL);
	else
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, w, h, 0, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glFinish();
	int err_dstex = glGetError();
	printf("FBO tex err results: %i %i\n", err_ctex, err_dstex);
	if(use_stencil)
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, dstex, 0);
	else
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, dstex, 0);
	glBindTexture(GL_TEXTURE_2D, 0);
	glDisable(GL_TEXTURE_2D);
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	printf("FBO validation: %04X (%04X == complete)\n", status, GL_FRAMEBUFFER_COMPLETE);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	if(status != GL_FRAMEBUFFER_COMPLETE)
	{
		printf("FRAMEBUFFER NOT COMPLETE - cleaning up and returning nil\n");
		// Clean up
		glDeleteTextures(1, &ctex);
		glDeleteTextures(1, &dstex);
		glDeleteFramebuffers(1, &handle);

		lua_pushnil(L);
		return 1;
	}

	// Create fbo_t
	fbo_t *fbo = lua_newuserdata(L, sizeof(fbo_t));
	fbo->udtype = UD_FBO;
	fbo->handle = handle;
	fbo->ctex = ctex;
	fbo->dstex = dstex;
	fbo->width = w;
	fbo->height = h;
	lua_newtable(L);
	lua_pushcfunction(L, fbo_gc_lua);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);

	// Return!
	return 1;
	

#endif
}

int icelua_fn_client_fbo_use(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	if(!gl_use_fbo)
		return luaL_error(L, "FBOs not enabled!");
	if(!(GLAD_GL_ARB_framebuffer_object))
		return luaL_error(L, "FBOs not supported by this GPU!");

	if(lua_isnil(L, 1))
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		//glFinish();
		return 0;
	}

	fbo_t *fbo = lua_touserdata(L, 1);
	if(fbo == NULL || fbo->udtype != UD_FBO)
		return luaL_error(L, "not an FBO");

	glBindFramebuffer(GL_FRAMEBUFFER, fbo->handle);
	//glFinish();

	return 0;
#endif
}


