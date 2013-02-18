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
client.wav_cube_size(size)
	sets the size of a block in metres for sound calculations
*/
int icelua_fn_client_wav_cube_size(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	wav_cube_size = lua_tonumber(L, 1);
	if(wav_cube_size < 0.00001f)
		wav_cube_size = 0.00001f;
	
	return 0;
}

/*
chn = client.wav_play_global(wav, x, y, z, vol = 1.0, freq_mod = 1.0, vol_spread = ?)
	play the given sound at the given world position
	
	TODO: define vol_spread properly
	
	returns an index of a channel
	returns nil on error
*/
int icelua_fn_client_wav_play_global(lua_State *L)
{
	int top = icelua_assert_stack(L, 4, 7);
	
	wav_t *wav = (wav_t*)lua_touserdata(L, 1);
	if(wav == NULL || wav->udtype != UD_WAV)
		return luaL_error(L, "not a wav");
	float x = lua_tonumber(L, 2);
	float y = lua_tonumber(L, 3);
	float z = lua_tonumber(L, 4);
	float vol = (top < 5 ? 1.0f : lua_tonumber(L, 5));
	float freq_mod = (top < 6 ? 1.0f : lua_tonumber(L, 6));
	float vol_spread = (top < 7 ? 1.0f : lua_tonumber(L, 7));
	
	wavchn_t *chn = wav_chn_alloc(WCF_ACTIVE|WCF_GLOBAL, wav, x, y, z, vol, freq_mod, vol_spread);
	
	if(chn == NULL)
		// wups.
		return 0;
	
	lua_pushinteger(L, chn->idx);
	return 1;
}

/*
chn = client.wav_play_local(wav, x = 0.0, y = 0.0, z = 0.0, vol = 1.0, freq_mod = 1.0, vol_spread = ?)
	play the given sound at the given camera-local position
	
	returns an index of a channel
	returns nil on error
*/
int icelua_fn_client_wav_play_local(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 7);
	
	wav_t *wav = (wav_t*)lua_touserdata(L, 1);
	if(wav == NULL || wav->udtype != UD_WAV)
		return luaL_error(L, "not a wav");
	float x = (top < 2 ? 0.0f : lua_tonumber(L, 2));
	float y = (top < 3 ? 0.0f : lua_tonumber(L, 3));
	float z = (top < 4 ? 0.0f : lua_tonumber(L, 4));
	float vol = (top < 5 ? 1.0f : lua_tonumber(L, 5));
	float freq_mod = (top < 6 ? 1.0f : lua_tonumber(L, 6));
	float vol_spread = (top < 7 ? 1.0f : lua_tonumber(L, 7));
	
	wavchn_t *chn = wav_chn_alloc(WCF_ACTIVE, wav, x, y, z, vol, freq_mod, vol_spread);
	
	if(chn == NULL)
		// wups.
		return 0;
	
	lua_pushinteger(L, chn->idx);
	return 1;
}

/*
exists = client.wav_chn_exists(chn)
	checks if an allocated channel still exists
	
	if a channel stops, it is garbage collected
*/
int icelua_fn_client_wav_chn_exists(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	int cidx = lua_tointeger(L, 1);
	wavchn_t *wc = &wchn[cidx & (WAV_CHN_COUNT-1)];
	
	lua_pushboolean(L, wc->idx == cidx && (wc->flags & WCF_ACTIVE));
	return 1;
}

/*
success = client.wav_chn_update(chn, x = nil, y = nil, z = nil, vol = nil, freq_mod = nil, vol_spread = nil)
	updates information pertaining to a channel
	
	any field which is nil is not affected
	
	returns false if the channel no longer exists
*/
int icelua_fn_client_wav_chn_update(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 7);
	
	// TODO!
	int cidx = lua_tointeger(L, 1);
	wavchn_t *wc = &wchn[cidx & (WAV_CHN_COUNT-1)];
	int isactive = (wc->idx == cidx && (wc->flags & WCF_ACTIVE));
	
	if(isactive)
	{
		if(top >= 2 && !lua_isnil(L, 2))
			wc->x = lua_tonumber(L, 2);
		if(top >= 3 && !lua_isnil(L, 3))
			wc->y = lua_tonumber(L, 3);
		if(top >= 4 && !lua_isnil(L, 4))
			wc->z = lua_tonumber(L, 4);
		if(top >= 5 && !lua_isnil(L, 5))
			wc->vol = lua_tonumber(L, 5);
		if(top >= 6 && !lua_isnil(L, 6))
			wc->freq_mod = lua_tonumber(L, 6);
		if(top >= 7 && !lua_isnil(L, 7))
			wc->vol_spread = lua_tonumber(L, 7);
	}
	
	lua_pushboolean(L, isactive);
	return 1;
}

/*
client.wav_kill(chn)
	stops and removes a channel
	
	if chn == "true", kills all channels
*/
int icelua_fn_client_wav_kill(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	int i;
	
	// TODO!
	if(lua_isboolean(L, 1) && lua_toboolean(L, 1))
	{
		for(i = 0; i < WAV_CHN_COUNT; i++)
			wav_chn_kill(&wchn[i]);
		
		return 0;
	}
	
	if(!lua_isnumber(L, 1))
		return luaL_error(L, "not a number");
	
	int idx = lua_tointeger(L, 1);
	
	wav_chn_kill(&wchn[idx & (WAV_CHN_COUNT-1)]);
	
	return 0;
}
#endif

// common functions

/*
wav = common.wav_load(fname)
	loads a sound with filename "fname"
	remember to free it when you're done
	as this is only a light userdata
*/
int icelua_fn_common_wav_load(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	const char *fname = lua_tostring(L, 1);
	if(fname == NULL)
		return luaL_error(L, "filename must be a string");
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "wav");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	return 1;
}
/*
common.wav_free(wav)
	free the given sound
	if you don't do this then it's memoryleaktopia
	(plus i'm allowed to kill you)
*/
int icelua_fn_common_wav_free(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	wav_t *wav = (wav_t*)lua_touserdata(L, 1);
	if(wav == NULL || wav->udtype != UD_WAV)
		return luaL_error(L, "not a wav");
	
	wav_kill(wav);
	
	return 0;
}
