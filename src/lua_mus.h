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

#ifndef DEDI
/*
success = client.mus_play(mus, order=0, row=0)
	starts playing module "mus" at given order/row
*/
int icelua_fn_client_mus_play(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 3);

	it_module_t *mus = lua_touserdata(L, 1);
	if(mus == NULL || mus->header.magic[0] != 'I')
		return luaL_error(L, "not an ImpulseTracker module");
	int order = (top >= 2 ? lua_tointeger(L, 2) : 0);
	int row = (top >= 3 ? lua_tointeger(L, 3) : 0);

	// XXX: i should probably add a proper API to sackit for this
	// ^ why did I write this?
	if(icesackit_pb != NULL)
		sackit_playback_free(icesackit_pb);
	//icesackit_pb = sackit_playback_new(mus, 4096, 256, MIXER_IT214FS);
	icesackit_pb = sackit_playback_new2(mus, 4096, 256, fnlist_itmixer[MIXER_IT214FS], 4, wav_mfreq);
	if(icesackit_pb == NULL)
	{
		lua_pushboolean(L, 0);
		return 1;
	}
	icesackit_pb->process_order = order-1;
	icesackit_pb->break_row = row;
	icesackit_bufoffs = 4096;

	lua_pushboolean(L, 1);
	return 1;
}

/*
client.mus_stop()
	stops playing music
*/
int icelua_fn_client_mus_stop(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 0);

	if(icesackit_pb != NULL)
		sackit_playback_free(icesackit_pb);
	
	icesackit_pb = NULL;

	return 0;
}

/*
client.mus_vol_set(vol)
	sets the mixing volume for the music
*/
int icelua_fn_client_mus_vol_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	float vol = lua_tonumber(L, 1);
	icesackit_vol = vol;

	return 0;
}
#endif

// common functions

/*
mus = common.mus_load_it(fname)
	loads an ImpulseTracker module with filename "fname"
	remember to free it when you're done
	as this is only a light userdata
*/
int icelua_fn_common_mus_load_it(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "it");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	return 1;
}

/*
common.mus_free(wav)
	free the given module
	if you don't do this then it's memoryleaktopia
	(plus i'm allowed to kill you)

	MAKE SURE YOU HAVE CALLED client.mus_stop IF YOU WERE PLAYING THIS FILE
	otherwise expect a crash.
*/
int icelua_fn_common_mus_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
#ifdef DEDI
	uint8_t *mus = lua_touserdata(L, 1);
	if(mus == NULL || mus[0] != 'I')
		return luaL_error(L, "not an ImpulseTracker module");
	
	free(mus);
#else
	it_module_t *mus = lua_touserdata(L, 1);
	if(mus == NULL || mus->header.magic[0] != 'I')
		return luaL_error(L, "not an ImpulseTracker module");
	
	sackit_module_free(mus);
#endif

	return 0;
}

