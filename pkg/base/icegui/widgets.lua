-- look into actual drawing functionality!~

-- sketch listener and collision system:
--    rect and layers detection (derive layers from hierarchy)
--    onDown onUp onMove onClick(down+up inside collision) onDrag(down inside collision, movement) onKeyboard
--    when will mouse cursor be visible? important engine consideration!

-- with min_width(), min_height(), and inner() we should have all the tools necessary for packing.
-- 1. estimate the size of all the children. (recursive)
-- 2. sort the children in the order specified by the packer's manifest.
-- 3. iterate through the children, moving them to the positions and sizes desired as specified by the packing mode.

-- also something to note - when we draw we have to pass a clip rectangle upwards so that scrolling is possible.

local P = {}

local widget_mt = {}
function widget_mt.__add(a, b) a.add_child(b) return a end
function widget_mt.__sub(a, b) a.remove_child(b) return a end
function widget_mt.__tostring(a)
	return a.x.."x "..a.y.."y "..a.relx().."rx "..a.rely().."ry" 
end

function P.widget(options)

	local this = {x = options.x or 0, y = options.y or 0, 
		parent = options.parent or nil, 
		children = options.children or {}, 
		align_x = options.align_x or 0.5, align_y = options.align_y or 0.5}
	
	local width = options.width or 0
	local height = options.height or 0
	local margin_left = options.margin_left or 0
	local margin_right = options.margin_right or 0
	local margin_top = options.margin_top or 0
	local margin_bottom = options.margin_bottom or 0
	
	-- align 0 = top-left
	-- align 1 = bottom-right
	-- align 0.5 = center
	
	function this.width() return width end
	function this.height() return height end
	
	function this.margin_left() return margin_left end
	function this.margin_top() return margin_top end
	function this.margin_right() return margin_right end
	function this.margin_bottom() return margin_bottom end
	
	function this.min_width() return width end
	function this.min_height() return height end
	
	function this.relx()
		local pos = this.x - (this.width() * this.align_x)
		if this.parent == nil then return pos
		else return pos + this.parent.relx() end
	end
	
	function this.rely()
		local pos = this.y - (this.height() * this.align_y)
		if this.parent == nil then return pos
		else return pos + this.parent.rely() end
	end
	
	function this.l() return this.relx() end
	function this.t() return this.rely() end
	function this.r() return this.relx() + this.width() end	
	function this.b() return this.rely() + this.bottom() end	
	function this.cx() return this.relx() + this.width() * 0.5 end		
	function this.cy() return this.rely() + this.height() * 0.5 end
	
	function this.inner()
		local l = this.l() + this.margin_left()
		local t = this.t() + this.margin_top()
		local r = this.r() - this.margin_right()
		local b = this.b() - this.margin_bottom()
		return {x=l, y=t, left=l, top=t, right=r, bottom=b, 
			width=r-l, height=b-t, cx=l+(r-l)*0.5, cy=t+(b-t)*0.5}
	end
	
	function this.detach() if this.parent then this.parent.children[this] = nil; this.parent = nil end end
	function this.add_child(child) child.detach(); child.parent = this; this.children[child] = child end
	function this.remove_child(child) child.detach() end
	function this.remove_all_children() for k,child in pairs(this.children) do this.remove_child(child) end end
	function this.set_parent(parent) this.detach(); this.parent = parent; parent.children[this] = this end
	function this.despawn() 
		for k,child in pairs(this.children) do child.despawn() end this.remove_all_children()
	end
	
	setmetatable(this, widget_mt)

	return this
end

function P.widget_frame(x, y, width, height)
	local w = widget{x=x, y=y, width=width, height=height}
	
	-- presumably this is a drawing widget.
	-- the key distinction between this API and the Flash monstrosity I made is that I can readily mix
	-- drawing widgets and non-drawing widgets.
	
	-- so then, if a packer is just another child, that means that it can inherit the size of the parent's inner.
	-- but what the children "see" reported is what the packer wants to make available.
	-- bottom-up traversal. Now I'm remembering this part.
	-- most custom widgets use their reported width and height, and that's that, but packers don't.
	
	return w
end

if _REQUIREDNAME == nil then
	widgets = P
else
    _G[_REQUIREDNAME] = P
end

local test = P.widget{x=100, y=100}
print(test)
local test2 = P.widget{x=100, y=100}
print(test2)
test2.set_parent(test)
print(test2)

return P