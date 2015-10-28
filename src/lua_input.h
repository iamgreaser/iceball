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
int icelua_fn_client_mouse_lock_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
    // workaround for SDL2 not properly resetting state when
    // alt-tabbing
    SDL_SetWindowGrab(window, SDL_FALSE);
    SDL_SetRelativeMouseMode(SDL_FALSE);

    int lock = lua_toboolean(L, 1);
    if (lock) {
        SDL_SetWindowGrab(window, SDL_TRUE);
        SDL_SetRelativeMouseMode(SDL_TRUE);
    }
#endif
	
	return 0;
}

int icelua_fn_client_mouse_visible_set(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
	SDL_ShowCursor(lua_toboolean(L, 1));
#endif
	
	return 0;
}

int icelua_fn_client_mouse_warp(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
    SDL_WarpMouseInWindow(window, lua_tonumber(L, 1), lua_tonumber(L, 2));
#endif
	
	return 0;
}
