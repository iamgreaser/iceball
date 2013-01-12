-- Icegui widget layout library

local P = {}

local widget_mt = {}
function widget_mt.__add(a, b) a.add_child(b) return a end
function widget_mt.__sub(a, b) a.remove_child(b) return a end
function widget_mt.__tostring(a)
	return a.x.."x "..a.y.."y "..a.relx.."rx "..a.rely.."ry" 
end
function widget_mt.__index(self, key)
	local getters = rawget(self, "getter_keys")
	if getters[key] ~= nil then
		return getters[key]()
	else
		return rawget(self, key)
	end
end
function widget_mt.__newindex(self, key, value)
	local setters = rawget(self, "setter_keys")
	if setters[key] ~= nil then
		setters[key](value)
	else
		rawset(self, key, value)
	end
end

function P.widget(options)
	
	options = options or {}
	
	local getter_keys = {}
	local setter_keys = {}
	
	local this = { x = options.x or 0, y = options.y or 0, 
			 parent = options.parent or nil, 
			 children = options.children or {},
			 align_x = options.align_x or 0.5, 
			 align_y = options.align_y or 0.5,
			 width = options.width or 0,
			 height = options.height or 0,
			 margin_left = options.margin_left or 0,
			 margin_right = options.margin_right or 0,
			 margin_top = options.margin_top or 0,
			 margin_bottom = options.margin_bottom or 0,
			 getter_keys = getter_keys, setter_keys = setter_keys }
	
	-- align 0 = top-left
	-- align 1 = bottom-right
	-- align 0.5 = center
	
	function this.propogate_dirty() 
		this.dirty = true
		for k, v in pairs(this.children) do
			v.propogate_dirty()
		end
	end
	
	function setter_keys.x(v) rawset(this, 'x', v) this.propogate_dirty() end
	function setter_keys.y(v) rawset(this, 'y', v) this.propogate_dirty() end
	
	function setter_keys.width(v) rawset(this, 'width', v) this.propogate_dirty() end
	function setter_keys.height(v) rawset(this, 'height', v) this.propogate_dirty() end
	
	function setter_keys.margin_left(v) rawset(this, 'margin_left', v) this.propogate_dirty() end
	function setter_keys.margin_top(v) rawset(this, 'margin_top', v) this.propogate_dirty() end
	function setter_keys.margin_right(v) rawset(this, 'margin_right', v) this.propogate_dirty() end
	function setter_keys.margin_bottom(v) rawset(this, 'margin_bottom', v) this.propogate_dirty() end
	
	function getter_keys.min_width() return this.width end
	function setter_keys.min_width(v) error("cannot set widget.min_width externally") end
	function getter_keys.min_height() return this.height end
	function setter_keys.min_height(v) error("cannot set widget.min_height externally") end
	
	function getter_keys.relx()
		local pos = this.x - (this.width * this.align_x)
		if this.parent == nil then return pos
		else return this.parent.relx + this.parent.width * this.parent.align_x + pos end
	end
	function setter_keys.relx(v) 
		local pos = v + (this.width * this.align_x)
		if this.parent == nil then this.x = pos
		else this.x = pos - (this.parent.relx + this.parent.width * this.parent.align_x) end
	end
	
	function getter_keys.rely()
		local pos = this.y - (this.height * this.align_y)
		if this.parent == nil then return pos
		else return this.parent.rely + this.parent.height * this.parent.align_y + pos end
	end
	function setter_keys.rely(v) 
		local pos = v + (this.width * this.align_y)
		if this.parent == nil then this.y = pos
		else this.y = pos - (this.parent.rely + this.parent.height * this.parent.align_y) end
	end
	
	function getter_keys.l() return this.relx end
	function setter_keys.l(v) this.relx = v end
	function getter_keys.t() return this.rely end
	function setter_keys.t(v) this.rely = v end
	function getter_keys.r() return this.relx + this.width end    
	function setter_keys.r(v) this.relx = v - this.width end
	function getter_keys.b() return this.rely + this.height end    
	function setter_keys.b(v) this.rely = v - this.height end
	function getter_keys.cx() return this.relx + this.width * 0.5 end
	function setter_keys.cx(v) this.relx = v - this.width * 0.5 end
	function getter_keys.cy() return this.rely + this.height * 0.5 end
	function setter_keys.cy(v) this.rely = v - this.height * 0.5 end
	
	function this.inner()
		local l = this.l() + this.margin_left()
		local t = this.t() + this.margin_top()
		local r = this.r() - this.margin_right()
		local b = this.b() - this.margin_bottom()
		return {x=l, y=t, left=l, top=t, right=r, bottom=b, 
			width=r-l, height=b-t, cx=l+(r-l)*0.5, cy=t+(b-t)*0.5}
	end
	
	function this.aabb(x, y, w, h)
		return not (this.l>x or this.r<x+w or this.t>y or this.b<y+h)
	end
	
	function this.child_boundaries()
		local child_boundaries = {}
		local ct = 1
		for c_k, child in pairs(this.children) do
			for b_k, boundary in pairs(child.child_boundaries) do
				child_boundaries[ct] = boundary
				ct = ct + 1
			end
		end
		child_boundaries[ct] = {l=this.l, t=this.t, r=this.r, b=this.b}
		return child_boundaries
	end
	
	function getter_keys.full_dimensions()
		local boundaries = this.child_boundaries()
		local left = boundaries[1].l
		local top = boundaries[1].t
		local right = boundaries[1].r
		local bottom = boundaries[1].b
		for k, v in pairs(boundaries) do
			left = math.min(v.l, left)
			top = math.min(v.t, top)
			right = math.max(v.r, right)
			bottom = math.max(v.b, bottom)
		end
		return {l=left, t=top, r=right, b=bottom}
	end
	
	-- very simple aabb collision for mousing. returns the "first and deepest child".
	function this.collide(x, y, w, h)
		w = w or 1
		h = h or 1
		local hit = this.aabb(x, y, w, h)
		local result = this
		for k, v in pairs(this.children) do
			result = v.collide(x, y, w, h) or this
		end
		return result
	end
	
	setmetatable(this, widget_mt)
	
	-- stub method for graphics resource management
	function this.free() end 
	-- remove the parent-child connection but do not deallocate the object
	function this.detach() 
		if this.parent then 
			local pos = this.parent.get_child_position(this)
			table.remove(this.parent.children, pos)
			this.parent = nil
			return pos
		end 
		return nil
	end
	-- remove the parent-child connection but do not deallocate the object
	function 
		this.remove_child(child) child.detach() 
	end
	-- remove the parent-child connection but do not deallocate the objects
	function this.remove_all_children() for k,child in pairs(this.children) do this.remove_child(child) end end
	-- create a relationship between the parent and child's size and coordinates (with optional sort position)
	function this.add_child(child, position)
		if child.parent ~= this then
			position = position or #this.children+1 
			child.detach(); child.parent = this; 
			table.insert(this.children, position, child)
		end
	end
	-- create a relationship between the parent and child's size and coordinates
	function this.set_parent(parent) parent.add_child(this) end
	-- remove the object and its children and deallocate all memory
	function this.despawn() 
		this.detach(); while #this.children>0 do this.children[1].despawn() end this.free()
	end
	-- get the index of the child, or nil if it's not in this node
	function this.get_child_position(child)
		local i
		for i=1, #this.children do if this.children[i] == child then return i end end
		return nil
	end
	-- swap the children at the indicated index values
	function this.swap_indices(a, b)
		local tmp = this.children[a]
		this.children[a] = this.children[b]
		this.children[b] = tmp
	end
	-- swap the child objects (assuming they exist and are searchable in the children table)
	function this.swap_children(a, b)
		this.swap_children(this.get_child_position(a), this.get_child_position(b))
	end
	-- make the child the top-most element without disturbing other ordering
	function this.child_to_top(child) child.detach() this.add_child(child) end
	-- make the child the bottom-most element without disturbing other ordering
	function this.child_to_bottom(child) child.detach() this.add_child(child, 1) end

	-- when using spacers, this walks through the tree and reflows them
	function this.reflow() for k, v in pairs(this.children) do v.reflow() end end
	
	return this
end

-- Abstract spacer implementation
local function spacer(options)

	local this = P.widget(options)
	
	this.fixed_width = options.fixed_width or false
	this.fixed_height = options.fixed_height or false
	this.spread = options.spread or 0
	
	local width_auto = function()
		local b = this.child_boundaries()
		return b.r - b.l
	end	
	local height_auto = function()
		local b = this.child_boundaries()
		return b.b - b.t
	end
	
	this.getter_keys.width = function() 
		if this.fixed_width then return rawget(this, 'width') else return width_auto() end
	end
	this.getter_keys.height = function() 
		if this.fixed_height then return rawget(this, 'height') else return height_auto() end
	end
	
	this.getter_keys.min_width = function()
		local w = 0
		for k, v in pairs(this.children) do
			w = w + v.min_width
		end
		return w
	end
	
	this.getter_keys.min_height = function()
		local h = 0
		for k, v in pairs(this.children) do
			h = h + v.min_height
		end
		return h
	end
	
	return this
	
end

--[[ FIXME: We can use min_width and min_height some more to force percentage allocation
to achieve the minimally overlapped result. (This would mean refactoring the table gen a bit.) ]]

-- percentage allocation table
local function percentage_table(p, children, width)
	if p == nil then
		-- default: all elements get same %
		local c = #children
		local i
		p = {}
		for i=1,c do table.insert(p, i, 1./c) end
	elseif not (#children == #p) then
		error("mismatched # of children in percentage table: expected "..#children.." got "..#p)
	end
	
	local result = {}
	
	-- create a result positioning table that is each element centered inside their allocated %
	local i
	local pct = 0
	for i=1, #children do
		pct = pct + p[i]
		table.insert(result, i, pct - p[i]/2)
	end
	
	return result
end

-- Horizontal spacer
function P.hspacer(options)
	
	local this = spacer(options)
	
	function this.reflow()
	
		local children = this.children
		
		for k, v in pairs(children) do v.reflow() end
		
		local tw = 0
		
		if this.fixed_width then
			-- allocate space to the children inside the given width
			local w = this.width
			tw = w
			local p = percentage_table(this.percentage, this.children)
			local i = 1
			for i=1, #children do
				children[i].x = p[i]
			end
		else
			-- allocate in order, left-positioned, based on the 'spread' value
			local i = 1
			local pos = 0
			for i=1, #children do
				children[i].l = pos + this.relx
				pos = pos + this.spread + children[i].min_width
			end
			tw = pos - this.spread
		end
		
		-- final pass: fix up alignment
		tw = tw * -this.align_x
		
		for i=1, #children do
			children[i].x = children[i].x + tw
		end
		
		this.propogate_dirty()
		
	end
	
	return this
	
end

-- Vertical spacer
function P.vspacer(options)

	local this = spacer(options)

	function this.reflow()
	
		local children = this.children
		
		for k, v in pairs(children) do v.reflow() end
		
		local th = 0
		
		if this.fixed_height then
			-- allocate space to the children inside the given width
			local h = this.height
			th = h
			local p = percentage_table(this.percentage, this.children)
			local i = 1
			for i=1, #children do
				children[i].y = p[i]
			end
		else
			-- allocate in order, top-positioned, based on the 'spread' value
			local i = 1
			local pos = 0
			for i=1, #children do
				children[i].t = pos + this.rely
				pos = pos + this.spread + children[i].min_height
			end
			th = pos - this.spread
		end
		
		-- final pass: fix up alignment
		th = th * -this.align_y
		
		for i=1, #children do
			children[i].y = children[i].y + th
		end		
		
		this.propogate_dirty()
		
	end
	
	return this
	
end

if _REQUIREDNAME == nil then
	widgets = P
else
	_G[_REQUIREDNAME] = P
end

return P
