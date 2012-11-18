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

lang_en = {
	["join"] = function (p,t) return "* "..p.." has joined the "..t.." team" end
	["quit"] = function (p) return "* "..p.." disconnected" end
	["chteam"] = function (p) return "* "..p.." switched teams" end
	["chwpn"] = function (p) return "* "..p.." switched weapons" end
	["chat"] = function (p,m) return "<"..p.."> "..m end
	["kill"] = function (ps,pd,w) return ""..ps.." killed "..pd.." ("..w..")" end
	["diefall"] = function (p) return ""..p.." fell too far" end
	["tkill"] = function (ps,pd,w) return ""..ps.." teamkilled "..pd.." ("..w..")" end
}
