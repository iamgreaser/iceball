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
	cmp={0,0,0,0,3},
	num=3,
	str="0.0-3",
}

VERSION_MOD = {
	cmp={0,0,0,1},
	str="0.0-1"
}

VERSION_BUGS = {
{intro=nil, fix=1, msg="PMF models have the wrong Z value when close to the screen edges, and can be seen through walls"},
{intro=nil, fix=1, msg="PMF models are sometimes saved with garbage following the name"},
{intro=nil, fix=1, msg="Client does pathname security checks for non-clsave files"},
{intro=nil, fix=3, msg="common.img_fill not implemented (this wrapper will be somewhat slow)"},
{intro=nil, fix=nil, msg="Sound is not supported"},
}
