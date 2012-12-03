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

int icelua_fn_common_model_new(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 1);
	int bonemax = 5;
	
	if(top >= 1)
		bonemax = lua_tointeger(L, 1);
	if(bonemax < 0 || bonemax >= MODEL_BONE_MAX)
		return luaL_error(L, "cannot have %d bones, max is %d", bonemax, MODEL_BONE_MAX);
	
	model_t *pmf = model_new(bonemax);
	
	// TODO: add this to a clean-up linked list or something
	lua_pushlightuserdata(L, pmf);
	return 1;
}

int icelua_fn_common_model_load_pmf(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "pmf");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	return 1;
}

int icelua_fn_common_model_save_pmf(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL)
		return luaL_error(L, "not a model");
	const char *fname = lua_tostring(L, 2);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	if(L == lstate_server
		? !path_type_server_writable(path_get_type(fname))
		: !path_type_client_writable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot write to there");
	}
	
	lua_pushboolean(L, !model_save_pmf(pmf, fname));
	
	return 1;
}

int icelua_fn_common_model_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	model_free(pmf);
	
	return 0;
}

int icelua_fn_common_model_len(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	lua_pushinteger(L, pmf->bonelen);
	return 1;
}

int icelua_fn_common_model_bone_new(lua_State *L)
{
	// TODO: check for size limit
	
	int top = icelua_assert_stack(L, 1, 2);
	int ptmax = 20;
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	if(top >= 2)
		ptmax = lua_tointeger(L, 2);
	if(ptmax < 0 || ptmax >= MODEL_POINT_MAX)
		return luaL_error(L, "cannot have %d points, max is %d", ptmax, MODEL_POINT_MAX);
	
	// ensure there is room for this bone
	int tsize = pmf->bonelen+1;
	
	if(pmf->bonelen >= pmf->bonemax)
	{
		int csize = (pmf->bonemax*3)/2+1;
		if(csize < tsize)
			csize = tsize;
		
		pmf = model_extend(pmf, csize);
	}
	
	// now add it
	model_bone_t *bone = model_bone_new(pmf, ptmax);
	
	lua_pushlightuserdata(L, pmf);
	lua_pushinteger(L, bone->parent_idx);
	return 2;
}

int icelua_fn_common_model_bone_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 2);
	int boneidx;
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	boneidx = lua_tointeger(L, 2);
	if(boneidx < 0 || boneidx >= pmf->bonelen)
		return luaL_error(L, "bone index %d out of range, len is %d", boneidx, pmf->bonelen);
	
	model_bone_free(pmf->bones[boneidx]);
	
	return 0;
}

int icelua_fn_common_model_bone_get(lua_State *L)
{
	int i;
	int top = icelua_assert_stack(L, 2, 2);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	int boneidx = lua_tointeger(L, 2);
	if(boneidx < 0 || boneidx >= pmf->bonelen)
		return luaL_error(L, "bone index %d out of range, len is %d", boneidx, pmf->bonelen);
	model_bone_t *bone = pmf->bones[boneidx];
	
	// push args
	lua_pushstring(L, bone->name);
	lua_createtable(L, bone->ptlen, 0);
	
	// fill the table
	for(i = 0; i < bone->ptlen; i++)
	{
		model_point_t *pt = &(bone->pts[i]);
		
		lua_pushinteger(L, i+1);
		lua_createtable(L, 0, 7);
		
		lua_pushinteger(L, pt->radius);
		lua_setfield(L, -2, "radius");
		
		lua_pushinteger(L, pt->x);
		lua_setfield(L, -2, "x");
		lua_pushinteger(L, pt->y);
		lua_setfield(L, -2, "y");
		lua_pushinteger(L, pt->z);
		lua_setfield(L, -2, "z");
		
		lua_pushinteger(L, pt->r);
		lua_setfield(L, -2, "r");
		lua_pushinteger(L, pt->g);
		lua_setfield(L, -2, "g");
		lua_pushinteger(L, pt->b);
		lua_setfield(L, -2, "b");
		
		lua_settable(L, -3);
	}
	
	return 2;
}

int icelua_fn_common_model_bone_set(lua_State *L)
{
	int i;
	int top = icelua_assert_stack(L, 4, 4);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	int boneidx = lua_tointeger(L, 2);
	if(boneidx < 0 || boneidx >= pmf->bonelen)
		return luaL_error(L, "bone index %d out of range, len is %d", boneidx, pmf->bonelen);
	model_bone_t *bone = pmf->bones[boneidx];
	
	const char *name = lua_tostring(L, 3);
	if(name == NULL)
		return luaL_error(L, "bone name cannot be nil");
	if(strlen(name) > 15)
		return luaL_error(L, "bone name too long, was %d chars, max is 15", strlen(name));
	
	if(!lua_istable(L, 4))
		return luaL_error(L, "expected a table, got something else");
	
	// check if the bone is large enough
	
	int tsize = lua_objlen(L, 4);
	
	if(tsize > bone->ptmax)
	{
		int csize = (bone->ptmax*3)/2+1;
		if(csize < tsize)
			csize = tsize;
		
		//printf("bone extend %i %i %i\n", bone->ptmax, tsize, csize);
		bone = model_bone_extend(bone, csize);
	}
	
	// set the bone's name
	strcpy(bone->name, name);
	
	// load the table's contents
	bone->ptlen = 0;
	for(i = 0; i < tsize; i++)
	{
		lua_pushinteger(L, i+1);
		lua_gettable(L, 4);
		
		// note, bones will be rejected if:
		// - radius,x,y,z,r,g,b are missing
		int radius = icelua_force_get_integer(L, -1, "radius");
		int x = icelua_force_get_integer(L, -1, "x");
		int y = icelua_force_get_integer(L, -1, "y");
		int z = icelua_force_get_integer(L, -1, "z");
		int r = icelua_force_get_integer(L, -1, "r");
		int g = icelua_force_get_integer(L, -1, "g");
		int b = icelua_force_get_integer(L, -1, "b");
		
		lua_pop(L, 1);
		
		// - 0 <= radius < 65536 fails
		if(radius < 0 || radius >= 65536)
			return luaL_error(L, "radius out of range of 0 <= %d < 65536", radius);
		
		// - -32768 <= x,y,z < 32768 fails
		if(x < -32768 || x >= 32768)
			return luaL_error(L, "x out of range of -32768 <= %d < 32768", x);
		if(y < -32768 || y >= 32768)
			return luaL_error(L, "y out of range of -32768 <= %d < 32768", x);
		if(z < -32768 || z >= 32768)
			return luaL_error(L, "z out of range of -32768 <= %d < 32768", x);
		
		// - 0 <= r,g,b < 256 fails
		if(r < 0 || r >= 256)
			return luaL_error(L, "r out of range of 0 <= %d < 256", r);
		if(g < 0 || g >= 256)
			return luaL_error(L, "g out of range of 0 <= %d < 256", g);
		if(b < 0 || b >= 256)
			return luaL_error(L, "b out of range of 0 <= %d < 256", b);
		
		// add it in!
		model_point_t *pt = &(bone->pts[i]);
		
		pt->radius = radius;
		pt->x = x, pt->y = y, pt->z = z;
		pt->r = r, pt->g = g, pt->b = b;
		pt->resv1 = 0;
		
		bone->ptlen++;
	}
	
	return 0;
}

int icelua_fn_common_model_bone_find(lua_State *L)
{
	int i;
	int top = icelua_assert_stack(L, 2, 2);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	const char *name = lua_tostring(L, 2);
	if(name == NULL)
		return luaL_error(L, "name must be a string");
	
	for(i = 0; i < pmf->bonemax; i++)
	{
		model_bone_t *bone = pmf->bones[i];
		
		if(!strcmp(bone->name, name))
		{
			lua_pushinteger(L, i);
			return 1;
		}
	}
	
	lua_pushnil(L);
	return 1;
}

// client functions
int icelua_fn_client_model_render_bone_global(lua_State *L)
{
	int top = icelua_assert_stack(L, 9, 9);
	float px, py, pz;
	float ry, rx, ry2;
	float scale;
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	int boneidx = lua_tointeger(L, 2);
	if(boneidx < 0 || boneidx >= pmf->bonelen)
		return luaL_error(L, "bone index %d out of range, len is %d", boneidx, pmf->bonelen);
	model_bone_t *bone = pmf->bones[boneidx];
	
	px = lua_tonumber(L, 3);
	py = lua_tonumber(L, 4);
	pz = lua_tonumber(L, 5);
	
	ry = lua_tonumber(L, 6);
	rx = lua_tonumber(L, 7);
	ry2 = lua_tonumber(L, 8);
	
	scale = lua_tonumber(L, 9);
	
	render_pmf_bone(screen->pixels, screen->w, screen->h, screen->pitch/4, &tcam,
		bone, 0, px, py, pz, ry, rx, ry2, scale);
	
	return 0;
}

int icelua_fn_client_model_render_bone_local(lua_State *L)
{
	int top = icelua_assert_stack(L, 9, 9);
	float px, py, pz;
	float ry, rx, ry2;
	float scale;
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL || pmf->udtype != UD_PMF)
		return luaL_error(L, "not a model");
	
	int boneidx = lua_tointeger(L, 2);
	if(boneidx < 0 || boneidx >= pmf->bonelen)
		return luaL_error(L, "bone index %d out of range, len is %d", boneidx, pmf->bonelen);
	model_bone_t *bone = pmf->bones[boneidx];
	
	px = lua_tonumber(L, 3);
	py = lua_tonumber(L, 4);
	pz = lua_tonumber(L, 5);
	
	ry = lua_tonumber(L, 6);
	rx = lua_tonumber(L, 7);
	ry2 = lua_tonumber(L, 8);
	
	scale = lua_tonumber(L, 9);
	
	render_pmf_bone(screen->pixels, screen->w, screen->h, screen->pitch/4, &tcam,
		bone, 1, px, py, pz, ry, rx, ry2, scale);
	
	return 0;
}
