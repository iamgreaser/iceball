--[[
    This file is part of Ice Lua Components.

    Ice Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ice Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Ice Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]

VERSION_ENGINE = {
	cmp={0,1,1,1,0},
	num=4227072+1,
	str="0.1.1-1",
}

-- 0.1: 4194304
-- 0.1.1: 4227072

VERSION_BUGS = {
{intro=nil, fix=1, msg="PMF models have the wrong Z value when close to the screen edges, and can be seen through walls"},
{intro=nil, fix=1, msg="PMF models are sometimes saved with garbage following the name"},
{intro=nil, fix=1, msg="Client does pathname security checks for non-clsave files"},
{intro=nil, fix=3, msg="common.img_fill not implemented (this wrapper will be somewhat slow)"},
{intro=nil, fix=4, msg="Sound is not supported"},
{intro=4, fix=5, msg="Dedicated server build was broken"},
{intro=5, fix=6, msg="CRASHES ON CHANNEL WRAPAROUND - PLEASE UPDATE TO 0.0-6!"},
{intro=nil, fix=7, msg="Camera roll / camera_point_sky not implemented - drunken cam will not roll properly"},
{intro=nil, fix=8, msg="Renderer uses double-rect approximation of cube instead of using trapezia"},
{intro=nil, fix=9, msg="Mouse warping not implemented"},
{intro=nil, fix=10, msg="Immediate ceiling isn't drawn"},
{intro=nil, fix=11, msg="Blocks appear inverted in common cases"},
{intro=nil, fix=12, msg="TGA loader prone to crashing on unsanitised data"},
{intro=nil, fix=13, msg="No per-face shading"},
{intro=nil, fix=14, msg="Color conversion functions are using hacky Lua code"},
{intro=nil, fix=16, msg="Per-face shading is only preliminary"},
{intro=nil, fix=17, msg="OpenMP not supported"},
{intro=nil, fix=19, msg="OpenGL not supported"},
{intro=19, fix=22, msg="Preliminary OpenGL support (fog not supported yet)"},
{intro=19, fix=21, msg="OpenGL renderer ignores islocal flag when rendering PMFs"},
{intro=21, fix=22, msg="PMF renderer does not update bones when redefined"},
{renderer="gl", intro=19, fix=23, msg="[OpenGL] texture rendering is slow"},
{renderer="gl", intro=19, fix=24, msg="[OpenGL] VBOs not supported"},
{intro=nil, fix=26, msg="TODO: give changelog for -25/-26 (which I think are the same version more or less)"},
{intro=nil, fix=27, msg="Altered the international keyboard thing to be more backwards compatible"},
{intro=25, fix=27, msg="THIS VERSION IS INCOMPATIBLE. PLEASE UPGRADE TO 0.0-27 AT LEAST."},
{intro=nil, fix=28, msg="Sound loader only loads first half of 16-bit samples correctly"},
{renderer="gl", intro=19, fix=29, msg="[OpenGL] Crashes on map creation (as opposed to map loading)"},
{intro=nil, fix=30, msg="clsave/config.json not supported"},
{intro=30, fix=31, msg="broke dedicated server build... again"},
{intro=nil, fix=32, msg=".it module music not supported"},
{intro=32, fix=nil, msg=".it module music might have stability issues. If it crashes, please tell us :)"},
{intro=nil, fix=34, msg="Server must be manually seeded"},
{intro=33, fix=34, msg="A few compilation warnings that shouldn't be there"},
{renderer="gl", intro=22, fix=35, msg="[OpenGL] Smooth lighting not supported"},
{renderer="gl", intro=35, fix=nil, msg="[OpenGL] Smooth lighting of PMF models not supported"},
{renderer="softgm", intro=37, fix=39, msg="[softgm] Preliminary smooth lighting (WIP)"},
{renderer="gl", intro=22, fix=38, msg="[OpenGL] Rendering tends to stutter on some cards"},
{renderer="gl", intro=38, fix=nil, msg="[OpenGL] Preliminary stutter-reduced rendering (WIP)"},
{renderer="gl", intro=22, fix=40, msg="[OpenGL] Chunks rendering options not supported in game engine config file"},
{renderer="gl", intro=22, fix=41, msg="[OpenGL] option to disable VBOs not available"},
{renderer="gl", intro=22, fix=42, msg="[OpenGL] lack of support for cards w/o non-power-of-2 texture support"},
{intro=nil, fix=43, msg="File transfer cancellation not supported"},
{intro=nil, fix=44, msg="[Windows] MessageBox added to 0.0-44 telling people not to double-click the .exe files"},
{intro=nil, fix=44, msg="[Windows binary build] stdout/stderr is now moved to the commandline in 0.0-44 - upgrade!"},
{intro=nil, fix=45, msg="Inbuilt tutorial not available in this version"},
{intro=nil, fix=45, msg="libsackit is out of date and does not support IT 2.14p3 resonant filters"},
{renderer="gl", intro=22, fix=46, msg="[OpenGL] PMF models tend to z-fight"},
{intro=nil, fix=47, msg="Binary file loading/saving not supported"},
{renderer="gl", intro=nil, fix=48, msg="[OpenGL] Chunk count is static and does not adapt to different fog values"},
{intro=nil, fix=48, msg="No way to determine from the Lua end what renderer a client is using"},
{renderer="gl", intro=nil, fix=48, msg="[OpenGL] Chunk generation pattern kinda sucks"},
{intro=nil, fix=49, msg="Kick not handled gracefully"},
{intro=49, fix=nil, msg="Kick message isn't communicated properly"},
{intro=nil, fix=50, msg="Network handle architecture changed. If it breaks, upgrade. If your mods break, FIX THEM."},
{intro=nil, fix=51, msg="ENet protocol not supported"},
{intro=51, fix=52, msg="Server tends to crash when a TCP connection loads and there's at least one other client still connected"},
{intro=51, fix=53, msg="Local mode (-s) broken and causes a crash"},
{intro=nil, fix=53, msg="Timing accuracy somewhat bad (uses a float instead of a double, mostly an issue for sec_current)"},
{intro=nil, fix=53, msg="There are some weird network stability issues"},
{intro=nil, fix=4194304+0, msg="Binary files don't have a type name"},
{intro=nil, fix=4194304+0, msg="JSON files cannot be remotely sent to clients"},
{intro=nil, fix=4194304+1, msg="Arbitrary TCP connections not supported"},
{intro=4194304+1, fix=4194304+2, msg="This build doesn't actually compile on not-windows because itoa isn't a real function."},
{intro=4194304+1, fix=4194304+2, msg="Raw TCP connection throws an error on failure"},
{intro=4194304+1, fix=4194304+9, msg="Raw TCP appears to ignore the whitelist on the client side"},
{intro=nil, fix=nil, msg="Occasional crash in sackit_module_free on common.mus_free - this is probably a sackit bug."},
{intro=nil, fix=nil, msg="Sound distance attenuation affected by zoom (workaround implemented)"},
{intro=nil, fix=4194304+3, msg="[OpenGL] Frustum culling not supported"},
{intro=nil, fix=4194304+4, msg="[OpenGL] Ambient occlusion on sides not rendered equally"},
{intro=4194304+4, fix=4194304+5, msg="[OpenGL] Ambient occlusion on sides rendered very unequally on very rare GPUs such as the Intel 3000HD"},
{intro=4194304+3, fix=4194304+7, msg="[OpenGL] Frustum culling improved in later versions"},
{intro=4194304+3, fix=nil, msg="[OpenGL] Frustum culling still screws up on occasion"},
{intro=nil, fix=4194304+8, msg="Occasional crash when music is stopped"},
{intro=4194304+1, fix=4194304+9, msg="Raw TCP still throws a lua error if it can't connect"},
{intro=nil, fix=4227072+1, msg="Arbitrary UDP connections not supported"},
{intro=4227072+1, fix=nil, msg="Raw UDP support might be a bit flaky - if you find bugs, please tell us!"},
}

