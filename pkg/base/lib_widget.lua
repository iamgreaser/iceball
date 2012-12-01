if client then

-- last goals for today:
-- add a tostring, create an in-game test - 
-- sketch an events system

widget_counter = 0
all_widgets = []

function reset_widgets()
	all_widgets = [] widget_counter = 0
end

function widget(x, y, width, height)
	while(all_widgets[widget_counter] != nil) do widget_counter += 1 end
	local this = {id=widget_counter, x=x, y=y, parent=nil, children=[], align_x = 0.5, align_y = 0.5}
	all_widgets[widget_counter] = this
	widget_counter += 1
	
	-- align 0 = top-left
	-- align 1 = bottom-right
	-- align 0.5 = center
	
	function this.width() return width end
	function this.height() return height end
	
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
	
	function this.detach() this.parent.children[this.id] = nil; this.parent = nil end
	function this.add_child(child) child.detach(); child.parent = this; this.children[child.id] = child end
	function this.remove_child(child) child.detach() end
	function this.remove_all_children() for k,child in pairs(this.children) this.remove_child(child) end
	function this.set_parent(parent) this.detach(); this.parent = parent; parent.children[this.id] = this end
	function this.despawn() this.remove_all_children() all_widgets[this.id] = nil; end
	function this.despawn_all() for k,child in pairs(this.children) child.despawn_all() end this.despawn() end
	
	this.mt = {}
	function this.mt.__add(a, b) a.add_child(b) return a end
	function this.mt.__sub(a, b) a.remove_child(b) return a end
	
	setmetatable(this, this.mt)

	return this
end

end