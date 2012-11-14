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

function collect_new_prioq(fn_compare)
	local this = {} this.this = this
	
	local DEBUG_HEAP_ASSERT = false
	
	function this.clear()
		this.q = {}
	end
	
	local function prv_debug_check_heap(idx)
		local cidx = idx*2
		if cidx > #(this.q) then return end
		
		if fn_compare(this.q[cidx], this.q[idx]) then error("heap check failed") end
		prv_debug_check_heap(cidx)
		if cidx+1 <= #(this.q) then
			if fn_compare(this.q[cidx+1], this.q[idx]) then error("heap check failed") end
			prv_debug_check_heap(cidx+1)
		end
	end
	
	local function prv_sift_down(idx)
		while idx*2 <= #(this.q) do
			-- find highest prio child
			local cidx = idx*2
			if cidx+1 <= #(this.q) and fn_compare(this.q[cidx+1], this.q[cidx]) then
				cidx = cidx + 1
			end
			
			-- swap if necessary
			if fn_compare(this.q[cidx], this.q[idx]) then
				this.q[idx], this.q[cidx] = this.q[cidx], this.q[idx]
				idx = cidx
			else
				break
			end
		end
	end
	
	function this.push(v)
		local idx = #(this.q)+1
		this.q[idx] = v
		
		-- sift up
		while idx > 1 do
			-- check parent
			local pidx = math.floor(idx/2)
			if fn_compare(this.q[idx], this.q[pidx]) then
				this.q[idx], this.q[pidx] = this.q[pidx], this.q[idx]
				idx = pidx
			else
				break
			end
		end
		
		-- sift down
		prv_sift_down(idx)
		
		if DEBUG_HEAP_ASSERT then prv_debug_check_heap(1) end
	end
	
	function this.pop()
		local qlen = #(this.q)
		if qlen == 0 then return nil end
		local v = this.q[1]
		this.q[1] = this.q[qlen]
		this.q[qlen] = nil
		if this.q[1] then prv_sift_down(1) end
		if DEBUG_HEAP_ASSERT then prv_debug_check_heap(1) end
		return v
	end
	
	function this.empty()
		return #(this.q) == 0
	end
	
	this.clear()
	
	return this
end
