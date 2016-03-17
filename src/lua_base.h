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

int icelua_fn_base_loadfile(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	
	const char *fname = lua_tostring(L, 1);
	
	if(L == lstate_server
		? !path_type_server_readable(path_get_type(fname))
		: !path_type_client_readable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot read from there");
	}
	
	lua_getglobal(L, "common");
	lua_getfield(L, -1, "fetch_block");
	lua_remove(L, -2);
	lua_pushstring(L, "lua");
	lua_pushvalue(L, 1);
	lua_call(L, 2, 1);
	
	return 1;
}

int icelua_fn_base_dofile(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);

	lua_pushcfunction(L, icelua_fn_base_loadfile);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);

	// TODO: pcall this
	lua_call(L, 0, 0);

	return 0;
}

static const int sentinel = 0;

// Attempt to fetch requested module from multiple possible lookup paths
// i.e. "derp.herp" -> {"pkg/derp/herp.lua", "pkg/derp/herp/init.lua", ...}
// Params: mod_name
// Returns chunk if found, errors if not
static int icelua_fn_base_require_helper(lua_State *L)
{
	// mod_name = stack[1]
	const char *mod_name = luaL_checkstring(L, 1);
	// mod_path = stack[2]  -- Convert . to /
	const char *mod_path = luaL_gsub(L, mod_name, ".", "/");

	// paths = stack[3] = ICELUA_REQUIRE_PATH
	lua_getfield(L, LUA_REGISTRYINDEX, "ICELUA_REQUIRE_PATH");

	for (int i = 1;; i++) {
		// path_template = stack[4]
		lua_rawgeti(L, 3, i);
		if (lua_isnil(L, -1)) {
			// End of list
			lua_pop(L, 1);  // Pop off nil
			break;
		}
		lua_pushcfunction(L, icelua_fn_base_loadfile);
		// file_path = stack[6]  -- sub mod_path into path_template in place of "?"
		luaL_gsub(L, lua_tostring(L, 4), "?", lua_tostring(L, 2));
		if(lua_pcall(L, 1, 1, 0) == 0 && !lua_isnil(L, -1)) {
			// Loaded! Return loadfile return value
			return 1;
		}  // else, continue looking
		lua_pop(L, 2);  // Pop off path value and loadfile result
	}

	// Module not found in any of paths
	luaL_error(L, "module " LUA_QS " not found", mod_name);
	return 0;
}

int icelua_fn_base_require(lua_State *L)
{
	// TODO: Do we want to offer the functionality that the vanilla
	// package module provides? i.e. custom loaders, search path, etc.?
	// We don't use the builtin one as we'd have to remove a lot of stuff
	// to ensure security, so this is easier. If we want full functionality
	// though, that may be something to look into. - rakiru

	int top = icelua_assert_stack(L, 1, 1);

	// mod_name = stack[1]
	const char *mod_name = luaL_checkstring(L, 1);

	// loaded = stack[2] = LUA_REGISTRYINDEX["_LOADED"]
	lua_getfield(L, LUA_REGISTRYINDEX, "_LOADED");
	// if loaded == nil
	if (lua_isnil(L, 2)) {
		lua_pop(L, 2);
		// loaded = LUA_REGISTRYINDEX["_LOADED"] = {}
		lua_createtable(L, 0, 2);
		lua_pushvalue(L, 2);  // Dupe table since setfield pops but we want a copy remaining
		lua_setfield(L, LUA_REGISTRYINDEX, "_LOADED");
	}

	// module = stack[3] = loaded[mod_name]
	lua_getfield(L, 2, mod_name);

	// module?
	if (lua_toboolean(L, 3)) {
		// Check for loops or previous error while loading
		if (lua_touserdata(L, 3) == ((void*)&sentinel)) {
			luaL_error(L, "loop or previous error loading module " LUA_QS, mod_name);
		}
		// Already loaded successfully
		return 1;
	}
	lua_pop(L, 1);  // Remove nil module from stack

	// Set sentinel to detect loops/error on future require(mod_name)
	lua_pushlightuserdata(L, (void*)&sentinel);
	lua_setfield(L, 2, mod_name);

	// Attempt module path lookup
	// module_file = stack[3] = loadfile(mod_name) magic
	lua_pushcfunction(L, icelua_fn_base_require_helper);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);

	// module = stack[3] = module_file(mod_name)  -- module_file is popped
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);

	// if module == nil then module = true
	if (lua_isnil(L, 3)) {
		lua_pop(L, 1);  // Remove nil from stack
		lua_pushboolean(L, 1);  // Push true in its place
	}

	// loaded[mod_name] = module
	lua_pushvalue(L, 3);  // Dupe value as setfield pops
	lua_setfield(L, 2, mod_name);

	// return module
	return 1;
}

// Install package related stuff to state
void icelua_openpackage(lua_State *L)
{
	// We're not providing most of `package` anyway, so just make this a table
	// instead of a string as in `package.path` - rakiru
	// TODO: Actually, keeping as a hardcoded, internal path allows some
	// optimisations, // like doing the lookup server-side to avoid the extra
	// latency for files further down the list of paths.

	int key = 1;

	// Note: Ensure you alter this value if adding/removing paths
	lua_createtable(L, 5, 0);

	// Most packages will be in pkg/
	lua_pushinteger(L, key++);
	lua_pushstring(L, "pkg/?.lua");
	lua_settable(L, -3);

	lua_pushinteger(L, key++);
	lua_pushstring(L, "pkg/?/init.lua");
	lua_settable(L, -3);

	//  3rd party libs can go here without cluttering up the base pkg/ dir
	lua_pushinteger(L, key++);
	lua_pushstring(L, "pkg/vendor/?.lua");
	lua_settable(L, -3);

	lua_pushinteger(L, key++);
	lua_pushstring(L, "pkg/vendor/?/init.lua");
	lua_settable(L, -3);

	// On the off-chance you wanted to load code from clsave/svsave or whatever
	lua_pushinteger(L, key++);
	lua_pushstring(L, "?.lua");
	lua_settable(L, -3);

	lua_setfield(L, LUA_REGISTRYINDEX, "ICELUA_REQUIRE_PATH");
}
