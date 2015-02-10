
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

// TODO: this would be a good place to put stencil op stuff in

// client functions
#if 0
int icelua_fn_client_(lua_State *L)
{
	int top = icelua_assert_stack(L, 8, 9);
#ifdef DEDI
	return luaL_error(L, "EDOOFUS: why the hell is this being called in the dedi version?");
#else
#endif
	return 0;
}
#endif

