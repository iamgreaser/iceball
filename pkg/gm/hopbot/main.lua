do

local s_new_player = new_player
function new_player(...)
	local this = s_new_player(...)
	
	local s_tick = this.tick
	function this.tick(sec_current, sec_delta, ...)
		if this.alive and client and this == players[players.current] then
			local mvx, mvy, mvz, mvchange = this.calc_motion_local(sec_current, sec_delta)
			if this.ev_forward and this.ev_jump and (this.ev_left or this.ev_right) and math.abs(this.vx*this.vx+this.vz*this.vz) > 0.01 then
				-- calculate forward angle
				this.angy = math.atan2(this.vx, this.vz)
				
				-- calculate necessary hop offset
				--local mvd2 = 1.0/math.max(0.0001, math.sqrt(mvx*mvx + mvz*mvz))
				--local mspd = (mvx*this.vx + mvz*this.vz)*mvd2
				--print(mspd, mvd2)
				local mspd = math.sqrt(this.vx*this.vx + this.vz*this.vz) + 0.7
				local hopoffs = 0.0
				if mspd >= MODE_PSPEED_CONV_SPEEDCAP then
					hopoffs = math.acos(MODE_PSPEED_CONV_SPEEDCAP / mspd)
					--hopoffs = hopoffs + math.pi*1/40
				end

				-- tweak for side
				if this.ev_left then
					this.angy = this.angy - (math.pi*2*1/8-hopoffs)
				end
				if this.ev_right then
					this.angy = this.angy + (math.pi*2*1/8-hopoffs)
				end
			end
		end

		return s_tick(sec_current, sec_delta, ...)
	end

	return this
end

end
