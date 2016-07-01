--[[
    This file is derived from code from Ice Lua Components.

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

local thisid = ...

if client then
	weapon_models[thisid] = model_load({
		kv6 = {
			bdir = DIR_PORTALGUN,
			name = "portalgun.kv6",
			scale = 1.0/128.0,
		},
	}, {"kv6"})
end

weapon_names[thisid] = "Portal Gun"

return function (plr)
	local this = tpl_gun(plr, {
		dmg = {
			head = 0,
			body = 0,
			legs = 0,
		},
		block_damage = 0,

		ammo_clip = 10,
		ammo_reserve = 50,
		time_fire = 1/3,
		time_reload = 1/3,

		recoil_x = 0.0001,
		recoil_y = -0.05,

		model = client and (weapon_models[thisid] {
			filt = function(r,g,b)
				if r == 0 and g == 0 and b == 0 then
					return 0, 92, 172
				else
					return r, g, b
				end
			end
		}),

		name = "Portal Gun",
	})

	function this.reload()
		-- Close both portals
		plr.portal_list[1] = nil
		net_send(nil, common.net_pack("BBBhhhbbbbbb", PKT_PORTALGUN_SET,
			0, 1, cx, cy, cz,
			dx, dy, dz, 0, 0, 0))
		plr.portal_list[2] = nil
		net_send(nil, common.net_pack("BBBhhhbbbbbb", PKT_PORTALGUN_SET,
			0, 2, cx, cy, cz,
			dx, dy, dz, 0, 0, 0))
	end

	local s_tick = this.tick
	function this.tick(sec_current, sec_delta, ...)
		this.ammo_clip = 10
		return s_tick(sec_current, sec_delta, ...)
	end

	function this.textgen()
		local col = 0xFFC0C0C0
		return col, ((plr.portal_list[1] and "0") or "-")..
			" "..((plr.portal_list[2] and "0") or "-")
	end

	function this.click(button, state)
		if button == 1 or button == 3 then
			-- LMB
			if button == 1 then
				this.set_color(0, 92, 172)
			else
				this.set_color(240, 92, 28)
			end
			if this.ammo_clip > 0 then
				if state then
					this.portal_select = (button==1 and 1) or 2
				end
				this.firing = state
			else
				-- Shouldn't happen!
				this.firing = false
				client.wav_play_global(wav_pin, plr.x, plr.y, plr.z)
				plr.reload_msg.visible = true
				plr.reload_msg.static_alarm{name='reloadviz',
					time=0.5, on_trigger=function() plr.reload_msg.visible = false end}
			end
		elseif button == 2 then
			-- RMB
			if hold_to_zoom then
				plr.zooming = state and not this.reloading
			else
				if state and not this.reloading then
					plr.zooming = not plr.zooming
				end
			end
		end
	end

	function this.prv_fire(sec_current)
		local xlen, ylen, zlen
		xlen, ylen, zlen = common.map_get_dims()

		if client then
			client.wav_play_global(this.cfg.shot_sound, plr.x, plr.y, plr.z)

			bcase_part_mdl = bcase_part_mdl or new_particle_model(250, 215, 0)
			particles_add(new_particle{
				x = plr.x,
				y = plr.y,
				z = plr.z,
				vx = math.sin(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				vy = 0.1 + math.random() * 0.25,
				vz = math.cos(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				model = bcase_part_mdl,
				size = 8,
				lifetime = 2
			})
		end

		net_send(nil, common.net_pack("BBB", PKT_PLR_GUN_SHOT, 0, 1))

		-- TODO: Better spread
		-- spread
		local angy = plr.angy + (this.cfg.spread * (math.random() - 0.5))
		local angx = plr.angx + (this.cfg.spread * (math.random() - 0.5))

		local sya = math.sin(angy)
		local cya = math.cos(angy)
		local sxa = math.sin(angx)
		local cxa = math.cos(angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa

		-- tracer
		if client then
			tracer_add(plr.x, plr.y, plr.z, angy, angx)
		end

		-- perform a trace
		portal_traces_enabled = false
		local d,cx1,cy1,cz1,cx2,cy2,cz2
		d,cx1,cy1,cz1,cx2,cy2,cz2
		= trace_map_ray_dist(plr.x+sya*0.4,plr.y,plr.z+cya*0.4, fwx,fwy,fwz, this.cfg.range)
		d = d or this.cfg.range
		portal_traces_enabled = true

		-- see if there's anyone we can kill
		local hurt_idx = nil
		local hurt_part = nil
		local hurt_part_idx = 0
		local hurt_dist = d*d
		local i,j

		for i=1,players.max do
			local p = players[i]
			if p and p ~= plr and p.alive then
				local dx = p.x-plr.x
				local dy = p.y-plr.y+0.1
				local dz = p.z-plr.z

				for j=1,3 do
					local dot, dd = isect_line_sphere_delta(dx,dy,dz,fwx,fwy,fwz)
					if dot and dot < 0.55 and dd < hurt_dist then
						hurt_idx = i
						hurt_dist = dd
						hurt_part_idx = j
						hurt_part = ({"head","body","legs"})[j]

						break
					end
					dy = dy + 1.0
				end
			end
		end

		--[==[
		if hurt_idx then
			if server then
				--[[
				players[hurt_idx].gun_damage(
					hurt_part, this.cfg.dmg[hurt_part], plr)
				]]
			else
				--[[
				net_send(nil, common.net_pack("BBB"
					, PKT_PLR_GUN_HIT, hurt_idx, hurt_part_idx))
				]]
				plr.show_hit()
			end
		end
		]==]
		if client then
			--[[
			net_send(nil, common.net_pack("BBB"
				, PKT_PLR_GUN_HIT, 0, 0))
			]]

			if cx2 and cy2 <= ylen-2 and cx2 >= 0 and cx2 < xlen and cz2 >= 0 and cz2 < zlen then
				print("Portal hit ("..cx2..", "..cy2..", "..cz2..") type "..this.portal_select)
				local dx,dy,dz = cx2-cx1, cy2-cy1, cz2-cz1
				dx = math.floor(dx + 0.5)
				dy = math.floor(dy + 0.5)
				dz = math.floor(dz + 0.5)
				print("Direction ("..dx..", "..dy..", "..dz..")")

				-- Check if valid...
				local valid = true

				-- CHECK: Ensure back is all solid, front is all clear
				local cx = math.floor(cx2)
				local cy = math.floor(cy2)
				local cz = math.floor(cz2)
				if valid then
					local i,j,k
					for i=-1,1 do
					for j=-1,1 do
					for k=-1,0 do
						if not valid then break end

						local x = cx+k*dx+i*dy+j*dz
						local y = cy+k*dy+i*dz+j*dx
						local z = cz+k*dz+i*dx+j*dy

						if k == 0 then
							if map_block_get(x,y,z) == nil then valid = false end
						else
							if map_block_get(x,y,z) ~= nil then valid = false end
						end
					end
					end
					end
				end

				if valid and dy == 0 and (dx ~= 0 or dz ~= 0) then
					plr.show_hit()
					plr.portal_list[this.portal_select] = {cx, cy, cz, dx, dy, dz, 0, -1, 0}
					if plr.portal_list[3-this.portal_select] then
						plr.portal_list[3-this.portal_select].va = nil
					end
					net_send(nil, common.net_pack("BBBhhhbbbbbb", PKT_PORTALGUN_SET,
						0, this.portal_select, cx, cy, cz,
						dx, dy, dz, 0, -1, 0))

				elseif valid and dy ~= 0 and (dx == 0 and dz == 0) then
					local sx, sz = 0, 0

					if math.abs(fwx) > math.abs(fwz) then
						sx = (fwx < 0 and -1) or 1
					else
						sz = (fwz < 0 and -1) or 1
					end

					sx = sx * dy
					sz = sz * dy

					plr.show_hit()
					plr.portal_list[this.portal_select] = {cx, cy, cz, dx, dy, dz, sx, 0, sz}
					if plr.portal_list[3-this.portal_select] then
						plr.portal_list[3-this.portal_select].va = nil
					end
					net_send(nil, common.net_pack("BBBhhhbbbbbb", PKT_PORTALGUN_SET,
						0, this.portal_select, cx, cy, cz,
						dx, dy, dz, sx, 0, sz))
				end
			end
		end  -- if hurt_idx

		-- apply recoil
		-- attempting to emulate classic behaviour provided i have it right
		plr.recoil(sec_current, this.cfg.recoil_y, this.cfg.recoil_x)
	end

	function this.set_color(new_r, new_g, new_b)
		this.cfg.model = client and (weapon_models[thisid] {
			filt = function(r,g,b)
				if r == 0 and g == 0 and b == 0 then
					return new_r, new_g, new_b
				else
					return r, g, b
				end
			end
		})
	end

	return this
end


