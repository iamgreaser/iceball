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

struct icelua_entry {
	int (*fn) (lua_State *L);
	char *name;
};

lua_State *lstate_client = NULL;
lua_State *lstate_server = NULL;

// helper functions
int icelua_assert_stack(lua_State *L, int smin, int smax)
{
	int top = lua_gettop(L);
	
	if(smin != -1 && top < smin)
		return luaL_error(L, "expected at least %d arguments, got %d", smin, top);
	if(smax != -1 && top > smax)
		return luaL_error(L, "expected at most %d arguments, got %d", smax, top);
	
	return top;
}

int icelua_force_get_integer(lua_State *L, int table, char *name)
{
	lua_getfield(L, table, name);
	
	if(!lua_isnumber(L, -1))
		return luaL_error(L, "expected integer for \"%s\", got something else", name);
	
	int ret = lua_tointeger(L, -1);
	lua_pop(L, 1);
	
	return ret;
}

// common functions
int icelua_fn_common_map_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// if no map, just give off nils
	if(map == NULL)
	{
		return 0;
	} else {
		lua_pushinteger(L, map->xlen);
		lua_pushinteger(L, map->ylen);
		lua_pushinteger(L, map->zlen);
		return 3;
	}
}

int icelua_fn_common_map_pillar_get(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	int px, pz;
	int i;
	
	px = lua_tointeger(L, 1);
	pz = lua_tointeger(L, 2);
	
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// if no map, return nil
	if(map == NULL)
		return 0;
	
	// get a pillar
	uint8_t *p = map->pillars[(pz&(map->zlen-1))*map->xlen+(px&(map->xlen-1))];
	
	// build the list
	int llen = 4*((255&(int)*p)+1);
	lua_createtable(L, llen, 0);
	p += 4;
	
	for(i = 1; i <= llen; i++)
	{
		lua_pushinteger(L, i);
		lua_pushinteger(L, *(p++));
		lua_settable(L, -3);
	}
	
	return 1;
}

int icelua_fn_common_map_pillar_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	int px, pz, tlen;
	int i;
	
	px = lua_tointeger(L, 1);
	pz = lua_tointeger(L, 2);
	if(!lua_istable(L, 3))
		return luaL_error(L, "expected a table, got something else");
	tlen = lua_objlen(L, 3);
	
	map_t *map = (L == lstate_server ? svmap : clmap);
	
	// if no map, ignore (for now)
	if(map == NULL)
		return 0;
	
	// validate that the table is not TOO large and is 4-byte aligned wrt size
	if((tlen&3) || tlen > 1024)
		return luaL_error(L, "table length %d invalid", tlen);
	
	// validate the table's input range
	for(i = 0; i < tlen; i++)
	{
		lua_pushinteger(L, 1+i);
		lua_gettable(L, 3);
		int v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		if(v < 0 || v > 255)
			return luaL_error(L, "value at index %d out of unsigned byte range (%d)"
				, 1+i, v);
	}
	
	// validate the table data
	i = 0;
	for(;;)
	{
		lua_pushinteger(L, 1+i+0);
		lua_gettable(L, 3);
		lua_pushinteger(L, 1+i+1);
		lua_gettable(L, 3);
		lua_pushinteger(L, 1+i+2);
		lua_gettable(L, 3);
		lua_pushinteger(L, 1+i+3);
		lua_gettable(L, 3);
		int n = lua_tointeger(L, -4);
		int s = lua_tointeger(L, -3);
		int e = lua_tointeger(L, -2);
		int a = lua_tointeger(L, -1);
		lua_pop(L, 4);
		
		//printf("%i %i | %i %i | %i %i %i %i\n",px,pz,i,tlen,n,s,e,a);
		
		// Note, we are not supporting the shenanigans you can do in VOXLAP.
		// Especially considering that editing said shenanigans causes issues.
		// Also noting that said shenanigans weren't all that exploited,
		// VOXLAP automatically corrects shenanigans when you edit stuff,
		// and pyspades has no support for such shenanigans.
		if(e+1 < s)
			return luaL_error(L, "pillar has end+1 < start (%d < %d)"
					, e+1, s);
		if(i != 0 && s < a)
			return luaL_error(L, "pillar has start < air (%d < %d)"
					, s, a);
		if(n != 0 && n-1 < e-s+1)
			return luaL_error(L, "pillar has length < top length (%d < %d)"
					, n-1, e-s+1);
		
		
		// NOTE: this doesn't validate the BGRT (colour/type) entries.
		int la = 0;
		if(n == 0)
		{
			int exlen = (e-s+1)*4+i+4;
			if(exlen != tlen)
				return luaL_error(L, "pillar table len should be %d, got %d instead"
					, exlen, tlen);
			break;
		} else {
			i += 4*n;
			// should always be colour on the bottom!
			if(i > tlen-4)
				return luaL_error(L, "pillar table overflow when validating");
		
		}
	}
	
	// expand the pillar data if necessary
	int idx = (pz&(map->zlen-1))*map->xlen+(px&(map->xlen-1));
	uint8_t *p = map->pillars[idx];
	if((p[0]+1)*4 < tlen)
	{
		p = map->pillars[idx] = realloc(p, tlen+4);
		p[0] = (tlen>>2)-1;
	}
	
	// transfer the table data
	p += 4;
	for(i = 1; i <= tlen; i++)
	{
		lua_pushinteger(L, i);
		lua_gettable(L, 3);
		*(p++) = (uint8_t)lua_tointeger(L, -1);
		lua_pop(L, 1);
	}
	
	return 0;
}

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
	
	model_t *pmf = model_load_pmf(fname);
	
	// TODO: add this to a clean-up linked list or something
	if(pmf == NULL)
		lua_pushnil(L);
	else
		lua_pushlightuserdata(L, pmf);
	
	return 1;
}

int icelua_fn_common_model_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL)
		return luaL_error(L, "not a model");
	
	model_free(pmf);
	
	return 0;
}

int icelua_fn_common_model_len(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL)
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
	if(pmf == NULL)
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
	if(pmf == NULL)
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
	if(pmf == NULL)
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
	if(pmf == NULL)
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
		
		printf("bone extend %i %i %i\n", bone->ptmax, tsize, csize);
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
	if(pmf == NULL)
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
int icelua_fn_client_mouse_lock_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	SDL_WM_GrabInput(lua_toboolean(L, 1)
		? SDL_GRAB_ON
		: SDL_GRAB_OFF);
	
	return 0;
}

int icelua_fn_client_mouse_visible_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	SDL_ShowCursor(lua_toboolean(L, 1));
	
	return 0;
}

int icelua_fn_client_camera_point(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 5);
	float dx, dy, dz;
	float zoom = 1.0f, roll = 0.0f;
	
	dx = lua_tonumber(L, 1);
	dy = lua_tonumber(L, 2);
	dz = lua_tonumber(L, 3);
	if(top <= 4)
		zoom = lua_tonumber(L, 4);
	if(top <= 5)
		roll = lua_tonumber(L, 5);
	
	cam_point_dir(&tcam, dx, dy, dz, zoom, roll);
	
	return 0;
}

int icelua_fn_client_camera_move_local(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	float dx, dy, dz;
	
	dx = lua_tonumber(L, 1);
	dy = lua_tonumber(L, 2);
	dz = lua_tonumber(L, 3);
	
	tcam.mpx += dx*tcam.mxx+dy*tcam.myx+dz*tcam.mzx;
	tcam.mpy += dx*tcam.mxy+dy*tcam.myy+dz*tcam.mzy;
	tcam.mpz += dx*tcam.mxz+dy*tcam.myz+dz*tcam.mzz;

	return 0;
}

int icelua_fn_client_camera_move_global(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	float dx, dy, dz;
	
	dx = lua_tonumber(L, 1);
	dy = lua_tonumber(L, 2);
	dz = lua_tonumber(L, 3);
	
	tcam.mpx += dx;
	tcam.mpy += dy;
	tcam.mpz += dz;

	return 0;
}

int icelua_fn_client_camera_move_to(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 3);
	float px, py, pz;
	
	px = lua_tonumber(L, 1);
	py = lua_tonumber(L, 2);
	pz = lua_tonumber(L, 3);
	
	tcam.mpx = px;
	tcam.mpy = py;
	tcam.mpz = pz;

	return 0;
}

int icelua_fn_client_camera_get_pos(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
	lua_pushnumber(L, tcam.mpx);
	lua_pushnumber(L, tcam.mpy);
	lua_pushnumber(L, tcam.mpz);
	
	return 3;
}

int icelua_fn_client_camera_get_forward(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
	lua_pushnumber(L, tcam.mzx);
	lua_pushnumber(L, tcam.mzy);
	lua_pushnumber(L, tcam.mzz);
	
	return 3;
}

int icelua_fn_client_model_render_bone_global(lua_State *L)
{
	int top = icelua_assert_stack(L, 8, 8);
	float px, py, pz;
	float rx, ry;
	float scale;
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL)
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
	
	scale = lua_tonumber(L, 8);
	
	render_pmf_bone(screen->pixels, screen->w, screen->h, screen->pitch/4, &tcam,
		bone, 0, px, py, pz, ry, rx, scale);
	
	return 0;
}

int icelua_fn_client_model_render_bone_local(lua_State *L)
{
	int top = icelua_assert_stack(L, 8, 8);
	float px, py, pz;
	float rx, ry;
	float scale;
	
	model_t *pmf = lua_touserdata(L, 1);
	if(pmf == NULL)
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
	
	scale = lua_tonumber(L, 8);
	
	render_pmf_bone(screen->pixels, screen->w, screen->h, screen->pitch/4, &tcam,
		bone, 1, px, py, pz, ry, rx, scale);
	
	return 0;
}

int icelua_fn_client_screen_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);
	
	lua_pushinteger(L, screen->w);
	lua_pushinteger(L, screen->h);
	
	return 2;
}

int icelua_fn_client_img_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	img_t *img = img_load_tga(fname);
	if(img == NULL)
		return 0;
	
	lua_pushlightuserdata(L, img);
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 3;
}

int icelua_fn_client_img_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL)
		return luaL_error(L, "not an image");
	
	img_free(img);
	
	return 0;
}

int icelua_fn_client_img_get_dims(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL)
		return luaL_error(L, "not an image");
	
	lua_pushinteger(L, img->head.width);
	lua_pushinteger(L, img->head.height);
	
	return 2;
}

int icelua_fn_client_img_blit(lua_State *L)
{
	int top = icelua_assert_stack(L, 3, 8);
	int dx, dy, bw, bh, sx, sy;
	uint32_t color;
	
	img_t *img = lua_touserdata(L, 1);
	if(img == NULL)
		return luaL_error(L, "not an image");
	
	dx = lua_tointeger(L, 2);
	dy = lua_tointeger(L, 3);
	bw = (top < 4 ? img->head.width : lua_tointeger(L, 4));
	bh = (top < 5 ? img->head.height : lua_tointeger(L, 5));
	sx = (top < 6 ? 0 : lua_tointeger(L, 6));
	sy = (top < 7 ? 0 : lua_tointeger(L, 7));
	color = (top < 8 ? 0xFFFFFFFF : (uint32_t)lua_tointeger(L, 8));
	
	render_blit_img(screen->pixels, screen->w, screen->h, screen->pitch/4,
		img, dx, dy, bw, bh, sx, sy, color);
	
	return 0;
}

// server functions

struct icelua_entry icelua_client[] = {
	{icelua_fn_client_mouse_lock_set, "mouse_lock_set"},
	{icelua_fn_client_mouse_visible_set, "mouse_visible_set"},
	{icelua_fn_client_camera_point, "camera_point"},
	{icelua_fn_client_camera_move_local, "camera_move_local"},
	{icelua_fn_client_camera_move_global, "camera_move_global"},
	{icelua_fn_client_camera_move_to, "camera_move_to"},
	{icelua_fn_client_camera_get_pos, "camera_get_pos"},
	{icelua_fn_client_camera_get_forward, "camera_get_forward"},
	{icelua_fn_client_screen_get_dims, "screen_get_dims"},
	{icelua_fn_client_img_load, "img_load"},
	{icelua_fn_client_img_free, "img_free"},
	{icelua_fn_client_img_get_dims, "img_get_dims"},
	{icelua_fn_client_img_blit, "img_blit"},
	{NULL, NULL}
};

struct icelua_entry icelua_server[] = {
	{NULL, NULL}
};
struct icelua_entry icelua_common[] = {
	{icelua_fn_common_map_get_dims, "map_get_dims"},
	{icelua_fn_common_map_pillar_get, "map_pillar_get"},
	{icelua_fn_common_map_pillar_set, "map_pillar_set"},
	{icelua_fn_common_model_new, "model_new"},
	{icelua_fn_common_model_load_pmf, "model_load_pmf"},
	{icelua_fn_common_model_free, "model_free"},
	{icelua_fn_common_model_len, "model_len"},
	{icelua_fn_common_model_bone_new, "model_bone_new"},
	{icelua_fn_common_model_bone_free, "model_bone_free"},
	{icelua_fn_common_model_bone_get, "model_bone_get"},
	{icelua_fn_common_model_bone_set, "model_bone_set"},
	{icelua_fn_common_model_bone_find, "model_bone_find"},
	{icelua_fn_client_model_render_bone_global, "model_render_bone_global"},
	{icelua_fn_client_model_render_bone_local, "model_render_bone_local"},
	
	{NULL, NULL}
};

struct icelua_entry icelua_common_client[] = {
	{NULL, NULL}
};

struct icelua_entry icelua_common_server[] = {
	{NULL, NULL}
};

void icelua_loadfuncs(lua_State *L, char *table, struct icelua_entry *fnlist)
{
	lua_getglobal(L, table);
	
	while(fnlist->fn != NULL)
	{
		lua_pushcfunction(L, fnlist->fn);
		lua_setfield (L, -2, fnlist->name);
		fnlist++;
	}
	
	lua_pop(L, 1);
}

void icelua_loadbasefuncs(lua_State *L)
{
	// load base library
	// TODO: whitelist the functions by spawning a new environment.
	// this is harder than it sounds.
	lua_pushcfunction(L, luaopen_base);
	lua_call(L, 0, 0);
	
	// here's the other two
	lua_pushcfunction(L, luaopen_string);
	lua_call(L, 0, 0);
	lua_pushcfunction(L, luaopen_math);
	lua_call(L, 0, 0);
}

int icelua_init(void)
{
	// create states
	lstate_client = luaL_newstate();
	lstate_server = luaL_newstate();
	
	// create tables
	lua_newtable(lstate_client);
	lua_setglobal(lstate_client, "client");
	lua_newtable(lstate_client);
	lua_setglobal(lstate_client, "common");
	
	lua_newtable(lstate_server);
	lua_setglobal(lstate_server, "server");
	lua_newtable(lstate_server);
	lua_setglobal(lstate_server, "common");
	
	// load stuff into them
	icelua_loadfuncs(lstate_client, "client", icelua_client);
	icelua_loadfuncs(lstate_server, "server", icelua_server);
	icelua_loadfuncs(lstate_client, "client", icelua_common);
	icelua_loadfuncs(lstate_server, "server", icelua_common);
	icelua_loadfuncs(lstate_client, "common", icelua_common);
	icelua_loadfuncs(lstate_server, "common", icelua_common);
	icelua_loadfuncs(lstate_client, "client", icelua_common_client);
	icelua_loadfuncs(lstate_server, "server", icelua_common_server);
	icelua_loadfuncs(lstate_client, "common", icelua_common_client);
	icelua_loadfuncs(lstate_server, "common", icelua_common_server);
	
	// load some lua base libraries
	icelua_loadbasefuncs(lstate_client);
	icelua_loadbasefuncs(lstate_server);
	
	/*
	NOTE:
	to call stuff, use lua_pcall.
	DO NOT use lua_call! if it fails, it will TERMINATE the program!
	*/
	
	// quick test
	// TODO: set up a "convert/filter file path" function
	// TODO: split the client/server inits
	if(luaL_loadfile(lstate_server, "pkg/base/main_server.lua") != 0)
	{
		printf("ERROR loading server Lua: %s\n", lua_tostring(lstate_server, -1));
		return 1;
	}
	
	if(luaL_loadfile(lstate_client, "pkg/base/main_client.lua") != 0)
	{
		printf("ERROR loading client Lua: %s\n", lua_tostring(lstate_client, -1));
		return 1;
	}
	
	if(lua_pcall(lstate_server, 0, 0, 0) != 0)
	{
		printf("ERROR running server Lua: %s\n", lua_tostring(lstate_server, -1));
		lua_pop(lstate_server, 1);
	}
	lua_pop(lstate_server, 1);
	
	if(lua_pcall(lstate_client, 0, 0, 0) != 0)
	{
		printf("ERROR running client Lua: %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
	}
	lua_pop(lstate_client, 1);
	
	return 0;
}

void icelua_deinit(void)
{
	// TODO!
}

