/*
    This file is part of Buld Then Snip.

    Buld Then Snip is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Buld Then Snip is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Buld Then Snip.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

int (*(btslua_client[])) (lua_State *L) = {
	NULL
};

int (*(btslua_server[])) (lua_State *L) = {
	NULL
};

int (*(btslua_common[])) (lua_State *L) = {
	NULL
};

int (*(btslua_common_client[])) (lua_State *L) = {
	NULL
};

int (*(btslua_common_server[])) (lua_State *L) = {
	NULL
};

int btslua_init(void)
{
	// TODO!
	return 0;
}

void btslua_deinit(void)
{
	// TODO!
}

