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
