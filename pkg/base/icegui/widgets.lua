-- look into actual drawing functionality!~
-- the client drawing code requires manual memory management:
-- we have to allocate a buffer and draw pixels to it
-- this code can't deal with that problem...
-- lib_gui will have to provide a layer that takes the abstract APIs here and adds drawing functions
-- on top. the abstract API can assist by adding a "dirty" flag so that cache management is straightforward.

-- sketch listener and collision system:
--    rect and layers detection (derive layers from hierarchy)
--    onDown onUp onMove onClick(down+up inside collision) onDrag(down inside collision, movement) onKeyboard
--    when will mouse cursor be visible? important engine consideration!

-- with min_width(), min_height(), and inner() we should have all the tools necessary for packing.
-- 1. estimate the size of all the children. (recursive)
-- 2. sort the children in the order specified by the packer's manifest.
-- 3. iterate through the children, moving them to the positions and sizes desired as specified by the packing mode.

-- also something to note - when we draw we have to pass a clip rectangle upwards so that scrolling is possible.
-- this isn't strictly necessary, but if the possibility is there, use it!

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
	
	function this.num_children()
		local ct = 0
		for k, v in pairs(this.children) do ct = ct + 1 end
		return ct
	end
	
	-- align 0 = top-left
	-- align 1 = bottom-right
	-- align 0.5 = center
	
	-- FIXME: some of the things that are disallowed as setters could be made settable with more effort.
	
	function setter_keys.x(v) rawset(this, 'x', v) this.dirty = true end
	function setter_keys.y(v) rawset(this, 'y', v) this.dirty = true end
	
	function setter_keys.width(v) rawset(this, 'width', v) this.dirty = true end
	function setter_keys.height(v) rawset(this, 'height', v) this.dirty = true end
	
	function setter_keys.margin_left(v) rawset(this, 'margin_left', v) this.dirty = true end
	function setter_keys.margin_top(v) rawset(this, 'margin_top', v) this.dirty = true end
	function setter_keys.margin_right(v) rawset(this, 'margin_right', v) this.dirty = true end
	function setter_keys.margin_bottom(v) rawset(this, 'margin_bottom', v) this.dirty = true end
	
	function getter_keys.min_width() return this.width end
	function setter_keys.min_width(v) error("cannot set widget.min_width externally") end
	function getter_keys.min_height() return this.height end
	function setter_keys.min_height(v) error("cannot set widget.min_height externally") end
	
	function getter_keys.relx()
		local pos = this.x - (this.width * this.align_x)
		if this.parent == nil then return pos
		else return this.parent.relx + pos end
	end
	function setter_keys.relx(v) error("cannot set widget.relx externally") end
	
	function getter_keys.rely()
		local pos = this.y - (this.height * this.align_y)
		if this.parent == nil then return pos
		else return this.parent.rely + pos end
	end
	function setter_keys.rely(v) error("cannot set widget.rely externally") end
	
	function getter_keys.l() return this.relx end
	function setter_keys.l(v) error("cannot set widget.l externally") end
	function getter_keys.t() return this.rely end
	function setter_keys.t(v) error("cannot set widget.t externally") end
	function getter_keys.r() return this.relx + this.width end    
	function setter_keys.r(v) error("cannot set widget.r externally") end
	function getter_keys.b() return this.rely + this.height end    
	function setter_keys.b(v) error("cannot set widget.b externally") end
	function getter_keys.cx() return this.relx + this.width * 0.5 end
	function setter_keys.cx(v) error("cannot set widget.cx externally") end
	function getter_keys.cy() return this.rely + this.height * 0.5 end
	function setter_keys.cy(v) error("cannot set widget.cy externally") end
	
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
	function this.detach() if this.parent then table.remove(this.children, this) this.parent = nil end end
	-- remove the parent-child connection but do not deallocate the object
	function this.remove_child(child) child.detach() end
	-- remove the parent-child connection but do not deallocate the objects
	function this.remove_all_children() for k,child in pairs(this.children) do this.remove_child(child) end end
	-- create a relationship between the parent and child's size and coordinates
	function this.add_child(child) child.detach(); child.parent = this; this.children[child] = child end
	-- create a relationship between the parent and child's size and coordinates
	function this.set_parent(parent) parent.add_child(this) end
	-- remove the object and its children and deallocate all memory
	function this.despawn() 
		this.detach(); for k,child in pairs(this.children) do child.despawn() end this.free()
	end

	return this
end

if _REQUIREDNAME == nil then
	widgets = P
else
	_G[_REQUIREDNAME] = P
end

return P
