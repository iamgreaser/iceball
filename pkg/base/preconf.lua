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

-- flags we need to add in early
MODE_NUB_KICKONJOIN = false

-- skins allowed 
SKIN_ENABLE_SRC = {"pmf", "kv6", "tga", "png", "wav", "it"}
SKIN_ENABLE = {}
do
	local i
	for i=1,#SKIN_ENABLE_SRC do
		SKIN_ENABLE[SKIN_ENABLE_SRC[i]] = true
	end
end

-- network throttling
NET_FLUSH_C2S = 0.02
NET_FLUSH_S2C = 0.02
NET_MAX_LAG = 50.0

-- base dir stuff
DIR_PKG_ROOT = DIR_PKG_ROOT or "pkg/base"
DIR_PKG_LIB = DIR_PKG_LIB or DIR_PKG_ROOT
DIR_PKG_PMF = DIR_PKG_PMF or DIR_PKG_ROOT.."/pmf"
DIR_PKG_KV6 = DIR_PKG_KV6 or DIR_PKG_ROOT.."/kv6"
DIR_PKG_GFX = DIR_PKG_GFX or DIR_PKG_ROOT.."/gfx"
DIR_PKG_WAV = DIR_PKG_WAV or DIR_PKG_ROOT.."/wav"
DIR_PKG_IT = DIR_PKG_IT or DIR_PKG_ROOT.."/it"
DIR_PKG_MAP = DIR_PKG_MAP or "pkg/maps"
DIR_SKIN = DIR_SKIN or "clsave/pub/skin"
GAME_MODE = "pkg/base/mode/mode_ctf.lua"

function skin_load(ftype, name, bdir, sdir)
	bdir = bdir or DIR_PKG_ROOT
	sdir = sdir or DIR_SKIN
	local hdl = SKIN_ENABLE[ftype] and common.fetch_block(ftype, sdir.."/"..name)
	print(hdl, bdir.."/"..name)
	hdl = hdl or common.fetch_block(ftype, bdir.."/"..name)
	print(hdl)
	return hdl
end

model_loaders = {}
dofile("pkg/base/lib_va.lua")

function model_load(mdict, prio, sdir)
	sdir = sdir or DIR_SKIN
	local i

	for i=1,#prio do
		--print(prio[i], sdir.."/"..mdict[prio[i]].name)
		local mdl = SKIN_ENABLE[prio[i]] and model_loaders[prio[i]](
			true, sdir.."/"..mdict[prio[i]].name, mdict[prio[i]])
		if mdl then return mdl end
	end

	for i=1,#prio do
		local mdl = model_loaders[prio[i]](
			true, mdict[prio[i]].bdir.."/"..mdict[prio[i]].name, mdict[prio[i]])
		if mdl then return mdl end
	end

	return nil
end

