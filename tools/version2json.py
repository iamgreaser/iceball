# coding=utf-8
"""
A script to convert the version.lua file into a JSON version, for use in
other languages.

Public domain where applicable, MIT license everywhere else.
"""
from __future__ import print_function

import ctypes
import json

### Load Lua shared library
for lib_name in ["../liblua", "liblua", "liblua.so"]:
    try:
        lua = ctypes.CDLL("../liblua")
        break
    except Exception:
        continue
else:
    print("Could not load Lua library")
    exit(1)

### Set up ctypes stuff for required functions
lua.luaL_newstate.restype = ctypes.c_void_p
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.luaL_loadstring.restype = ctypes.c_int
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.lua_pcall.restype = ctypes.c_int
lua.lua_gettop.restype = ctypes.c_int
lua.lua_typename.restype = ctypes.c_char_p

def lua_pop(L, n):
    return lua.lua_settop(L, -n - 1)

def lua_tostring(L, i):
    return lua.lua_tolstring(L, i, None)

### Some Lua constants
LUA_MULTRET = -1

# Pseudo-indices
LUA_REGISTRYINDEX = -10000
LUA_ENVIRONINDEX = -10001
LUA_GLOBALSINDEX = -10002

# Thread status
LUA_OK = 0  # Lua expects you to use literal 0, so this is made up
LUA_YIELD = 1
LUA_ERRRUN = 2
LUA_ERRSYNTAX = 3
LUA_ERRMEM = 4
LUA_ERRERR = 5

### Load versions file
try:
    with open("../pkg/base/version.lua", "r") as fp:
        versions_string = fp.read()
except Exception:
    print("Could not open version file")
    exit(1)

### Do magic
state = lua.luaL_newstate()

# Load string
result = lua.luaL_loadstring(state, versions_string)

if result != 0:
    print("Load string failed: %s" % result)
    exit(1)

# Run string
top = lua.lua_gettop(state)
result = lua.lua_pcall(state, 0, LUA_MULTRET, 0)

if result != 0:
    if result == LUA_ERRRUN:
        print("Runtime error while executing version file")
    elif result == LUA_ERRMEM:
        print("Memory allocation error while executing version file")
    elif result == LUA_ERRERR:
        print("Error while handling error while executing version file")
    else:
        print("Unknown error value while executing version file")
    exit(1)

return_count = lua.lua_gettop(state) - top

if return_count > 0:
    print("Unexpected return count")
    lua_pop(state, return_count)

# Get engine version
engine_versions = {}

lua.lua_getfield(state, LUA_GLOBALSINDEX, "VERSION_ENGINE")

lua.lua_getfield(state, -1, "str")
engine_versions["str"] = lua_tostring(state, -1)
lua_pop(state, 1)

lua.lua_getfield(state, -1, "num")
engine_versions["num"] = lua.lua_tointeger(state, -1, None)
lua_pop(state, 1)

engine_versions["cmp"] = []
lua.lua_getfield(state, -1, "cmp")
lua.lua_pushnil(state)
while lua.lua_next(state, -2) != 0:
    engine_versions["cmp"].append(lua.lua_tointeger(state, -1))
    lua_pop(state, 1)  # Remove value, keep key for lua_next()

lua_pop(state, 2)  # VERSION_ENGINE, cmp

# Get bugs
engine_bugs = []

lua.lua_getfield(state, LUA_GLOBALSINDEX, "VERSION_BUGS")

lua.lua_pushnil(state)
while lua.lua_next(state, -2) != 0:
    bug_entry = {}

    lua.lua_getfield(state, -1, "intro")
    bug_entry["intro"] = lua.lua_tointeger(state, -1)
    lua_pop(state, 1)

    lua.lua_getfield(state, -1, "fix")
    bug_entry["fix"] = lua.lua_tointeger(state, -1)
    lua_pop(state, 1)

    lua.lua_getfield(state, -1, "msg")
    bug_entry["msg"] = lua_tostring(state, -1)
    lua_pop(state, 1)

    engine_bugs.append(bug_entry)
    lua_pop(state, 1)  # Remove value, keep key for lua_next()

print("== Version ==")
for k, v in engine_versions.iteritems():
    print(" * %s - %s" % (k, v))
print()
print("== Bugs ==")
for bug in engine_bugs:
    print(" * %s" % bug["msg"])
    print("   intro: %s" % bug["intro"])
    print("   fixed: %s" % (bug["fix"] if bug["fix"] else "Not fixed"))

with open("version.json", "w") as fp:
    json.dump({"VERSION_ENGINE": engine_versions, "VERSION_BUGS": engine_bugs}, fp)
