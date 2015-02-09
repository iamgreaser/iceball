do

local s_new_intel = new_intel
local function wrap_intel(this)
	function this.get_name()
		return "ball"
	end

	return this
end

function new_intel(settings, ...)
	local this = s_new_intel(settings, ...)
	return wrap_intel(this)
end

if miscents then
	local i
	for i=1,#miscents do
		if miscents[i].type == "intel" then
			miscents[i] = wrap_intel(miscents[i])
		end
	end
end

local i
for i=1,#weapons do
	local s_weapon = weapons[i]
	weapons[i] = function(plr, cfg, ...)
		local this = s_weapon(plr, cfg, ...)

		local s_tick = this.tick
		function this.tick(sec_current, sec_delta, ...)
			if not plr.has_intel then return s_tick(sec_current, sec_delta, ...) end
		end

		local s_get_model = this.get_model
		function this.get_model(...)
			if not plr.has_intel then return s_get_model(...) end
			return plr.has_intel.mdl_intel
		end

		local s_render = this.render
		function this.render(px, py, pz, ya, xa, ya2, ...)
			if not plr.has_intel then return s_render(px, py, pz, ya, xa, ya2, ...) end
			return plr.has_intel.mdl_intel.render_global(
				px, py, pz, ya, xa, ya2, 1)
		end

		local s_click = this.click
		function this.click(button, state, ...)
			if not plr.has_intel then return s_click(button, state, ...) end
		end

		return this
	end
end

end

