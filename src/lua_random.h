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

// Notes:
// * There's no `get_seed` function because state is stored in a uint64, which
//   we can't shove into a double. We could return the original seed and steps
//   taken, but without a way to take arbitrary steps, this is pretty useless.
//   It would also require storing more state, but it's only 128 bits at the
//   moment, which is already pretty small for a PRNG.
// * We have jump now, but if we allow seeding with strings, then we could get
//   initial seeds that can't fit in Lua anyway.
// * We could return a hex string or something, but that would require us to
//   accept hex strings only. How would we deal with non-hex strings? Separate
//   function for hex strings? get_state/set_state, but allow arbitrary strings
//   (and hash them somehow) in seed?
// * We could add a clone function that creates a new one with the same state.
//   Useless for networking though.

int icelua_fn_cl_prng_seed(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 2);
	uint64_t seed = 0;  // TODO: Seed from time or something, if not given
	uint64_t stream = 0;
	if (top >= 1) {
		seed = (uint64_t)lua_tointeger(L, 1);
		if (top >= 2) {
			stream = (uint64_t)lua_tointeger(L, 2);
		}
	}
	prng_t *rng = lua_touserdata(L, lua_upvalueindex(1));
	prng_seed(rng, seed, stream);
	return 0;
}

// Simulates Lua's math.random
// 0 args: [0-1]
// 1 args: [0-max]
// 2 args: [min-max]
int icelua_fn_cl_prng_random(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 2);
	prng_t *rng = lua_touserdata(L, lua_upvalueindex(1));
	double result;
	if (top == 0) {
		result = prng_random_double(rng);
	} else {
		double minimum;
		double maximum;
		if (top == 1) {
			minimum = 0;
			maximum = lua_tonumber(L, 1);
		} else {
			minimum = lua_tonumber(L, 1);
			maximum = lua_tonumber(L, 2);
		}
		result = prng_random_double_range(rng, minimum, maximum);
	}
	lua_pushnumber(L, result);
	return 1;
}

int icelua_fn_cl_prng_jump(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	prng_t *rng = lua_touserdata(L, lua_upvalueindex(1));
	uint64_t step = (uint64_t)lua_tonumber(L, 1);
	prng_jump(rng, step);
	return 0;
}

int icelua_fn_common_prng_new(lua_State *L)
{
	int top = icelua_assert_stack(L, 0, 2);
	uint64_t seed = 0;  // TODO: Seed from time or something, if not given
	uint64_t stream = 0;
	if (top >= 1) {
		seed = (uint64_t)lua_tointeger(L, 1);
		if (top >= 2) {
			stream = (uint64_t)lua_tointeger(L, 2);
		}
	}

	// "this" table
	lua_createtable(L, 0, 4);

	// PRNG state - uses upvalues, not visible to Lua, but hey, GC
	prng_t *rng = lua_newuserdata(L, sizeof(prng_t));
	prng_seed(rng, seed, stream);

	lua_pushstring(L, "seed");  // Function name
	lua_pushvalue(L, -2);  // Duplicate RNG reference to top of stack
	lua_pushcclosure(L, &icelua_fn_cl_prng_seed, 1);  // Create closure, 1 upvalue (the RNG state)
	lua_settable(L, -4);  // Insert closure into table

	lua_pushstring(L, "random");  // Function name
	lua_pushvalue(L, -2);  // Duplicate RNG reference to top of stack
	lua_pushcclosure(L, &icelua_fn_cl_prng_random, 1);  // Create closure, 1 upvalue (the RNG state)
	lua_settable(L, -4);  // Insert closure into table

	lua_pushstring(L, "jump");  // Function name
	lua_pushvalue(L, -2);  // Duplicate RNG reference to top of stack
	lua_pushcclosure(L, &icelua_fn_cl_prng_jump, 1);  // Create closure, 1 upvalue (the RNG state)
	lua_settable(L, -4);  // Insert closure into table

	// Pop the RNG state off the stack.
	lua_pop(L, 1);

	return 1;

}
