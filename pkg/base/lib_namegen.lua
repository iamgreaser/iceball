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

-- yes, this is a great idea!

do
local n_base1 = {
	"b","c","ch","cl","d","fl","h","j","l","m","n","r","sh","spl","th","thr","w","z",
}
local n_base2 = {
	"alt","arp","at","each","erf","erp","iff","it","itt","ing","izz","og","ong","oog","oop","ooze","ug","urf",
}
local n_base3 = {
	"ator","ate","er","es","ette","ing","it","iser","le","ler","man","ner","son","ter"
}

function name_generate()
	local s1 = n_base1[math.floor(math.random()*#n_base1+1)]
	local s2 = n_base2[math.floor(math.random()*#n_base2+1)]
	local s3 = n_base3[math.floor(math.random()*#n_base3+1)]
	
	if string.sub(s2,-1,-1) == "e" and string.sub(s3,1,1) == "e" then
		s2 = string.sub(s2,1,-2)
	end
	
	local s = s1..s2..s3
	
	return s
end

--[[local i
for i=1,100 do
	print("name "..i..": "..name_generate())
end]]
end
