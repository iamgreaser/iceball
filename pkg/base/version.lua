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
	cmp={0,0,0,0,37},
	num=37,
	str="0.0-37",
}

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
{intro=19, fix=23, msg="[OpenGL] texture rendering is slow"},
{intro=19, fix=24, msg="[OpenGL] VBOs not supported"},
{intro=nil, fix=26, msg="TODO: give changelog for -25/-26 (which I think are the same version more or less)"},
{intro=nil, fix=27, msg="Altered the international keyboard thing to be more backwards compatible"},
{intro=25, fix=27, msg="THIS VERSION IS INCOMPATIBLE. PLEASE UPGRADE TO 0.0-27 AT LEAST."},
{intro=nil, fix=28, msg="Sound loader only loads first half of 16-bit samples correctly"},
{intro=19, fix=29, msg="[OpenGL] Crashes on map creation (as opposed to map loading)"},
{intro=nil, fix=30, msg="clsave/config.json not supported"},
{intro=30, fix=31, msg="broke dedicated server build... again"},
{intro=nil, fix=32, msg=".it module music not supported"},
{intro=32, fix=nil, msg=".it module music might have stability issues. If it crashes, please tell us :)"},
{intro=nil, fix=34, msg="Server must be manually seeded"},
{intro=33, fix=34, msg="A few compilation warnings that shouldn't be there"},
{intro=nil, fix=35, msg="[OpenGL] Smooth lighting not supported"},
{intro=35, fix=36, msg="[OpenGL] Smooth lighting of PMF models not supported"},
{intro=37, fix=nil, msg="[softgm] Preliminary smooth lighting (WIP)"},
}

