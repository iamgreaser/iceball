-- LTS: Last Team Standing. Try to not die!
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

MODE_LTS_STARTTIME = MODE_LTS_STARTTIME or 5
MODE_LTS_ROUNDTIME = MODE_LTS_ROUNDTIME or 300

local t_start = nil
local t_end = nil
local t_start_rem = nil

PKT_LTS_SET_TIMER = network.sys_alloc_packet()
network.sys_handle_s2c(PKT_LTS_SET_TIMER, "h", function (neth, cli, plr, sec_current, time, pkt)
	if time < 0 then
		t_start_rem = nil
	else
		t_start_rem = time
	end
end)

local function winning_team()
	local i
	local tpl = nil

	for i=1,players.max do
		if players[i] and players[i].alive then
			tpl = tpl or players[i].team
			if players[i].team ~= tpl then
				return nil
			end
		end
	end

	return tpl or -1
end

local function can_start_round()
	local i
	local tpl = nil

	for i=1,players.max do
		if players[i] then
			tpl = tpl or players[i].team
			if players[i].team ~= tpl then
				return true
			end
		end
	end

	return false
end

local function respawn_all()
	if not server then return end
	local i
	for i=1,players.max do
		if players[i] then
			players[i].spawn()
			net_broadcast(nil, common.net_pack("BBfffBB",
				PKT_PLR_SPAWN, i,
				players[i].x, players[i].y, players[i].z,
				players[i].angy*128/math.pi, players[i].angx*256/math.pi))
		end
	end
	if can_start_round() then
		net_broadcast(nil, common.net_pack("Bh",
			PKT_LTS_SET_TIMER, t_start_rem))
	end
end

function mode_reset()
	local i
	respawn_all()
	for i=0,teams.max do
		if teams[i] ~= nil then
			teams[i].score = 0
			net_broadcast(nil, common.net_pack("Bbh", PKT_TEAM_SCORE, i, teams[i].score))
		end
	end
end

function mode_create_server()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_CTF
end

function mode_create_client()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_CTF
end

function mode_relay_items(plr, neth)
	if t_start_rem then
		net_broadcast(nil, common.net_pack("Bh",
			PKT_LTS_SET_TIMER, math.ceil(t_start_rem)))
	end
end

local function tally_counts(timeup)
	if t_start ~= true then return nil end
	local team = winning_team()
	if team or timeup then
		if timeup then
			local tscores = {}
			local i
			for i=1,players.max do
				local p = players[i]
				if p and p.alive then
					local team = p.team
					tscores[team] = tscores[team] or 0
					tscores[team] = tscores[team] + 1
				end
			end
			local lgval = nil
			local lgidx = nil
			local k,v
			for k,v in pairs(tscores) do
				if lgidx == nil or v > lgval then
					lgidx = k
					lgval = v
				elseif v == lgval then
					lgidx = nil
				end
			end

			team = lgidx or -1
		end

		if team == -1 then
			net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
				"* Round ended in a tie :("))
		else
			teams[team].score = teams[team].score + 1
			net_broadcast(nil, common.net_pack("Bbh", PKT_TEAM_SCORE, team, teams[team].score))
			net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
				"* "..teams[team].name.." has won the round!"))
			local i
			for i=1,players.max do
				local p = players[i]
				if p and p.alive and p.team == team then
					p.score = p.score + 10
					p.update_score()
				end
			end
		end
		t_start = nil
		t_end = nil
		net_broadcast(nil, common.net_pack("Bh",
			PKT_LTS_SET_TIMER, -1))
	end
end

if server then
	local s_pkt_offer = network.sys_tab_handlers[PKT_PLR_OFFER].f
	network.sys_tab_handlers[PKT_PLR_OFFER].f = function (neth, cli, plr, sec_current, tidx, wpn, name, pkt, ...)
		local ret = s_pkt_offer(neth, cli, plr, sec_current, tidx, wpn, name, pkt, ...)
		if not plr then
			plr = players[cli.plrid]
			if plr and plr.alive then
				plr.deaths = plr.deaths - 1
				plr.set_health_damage(0, 0xFF800000, plr.name.." awaits the next round", nil)
			end
		end
		return ret
	end
end

local s_new_player = new_player
function new_player(...)
	local this = s_new_player(...)
	
	local s_tick = this.tick
	function this.tick(sec_current, sec_delta, ...)
		local ret = s_tick(sec_current, sec_delta, ...)
		this.t_respawn = nil
		if server then
			-- note, total hack. the server really needs an event system. --GM
			if t_start == nil then
				if can_start_round() then
					t_start = sec_current + MODE_LTS_STARTTIME
				end
			elseif t_start ~= true and t_start <= sec_current then
				net_broadcast(nil, common.net_pack("Bh",
					PKT_LTS_SET_TIMER, -1))
				t_start = true
				t_end = sec_current + MODE_LTS_ROUNDTIME
				respawn_all()
			elseif t_start ~= true then
				local oldrem = t_start_rem
				t_start_rem = math.ceil(t_start - sec_current)
				if t_start_rem ~= oldrem then
					net_broadcast(nil, common.net_pack("Bh",
						PKT_LTS_SET_TIMER, t_start_rem))
				end
			elseif t_end and sec_current >= t_end then
				tally_counts(true)
			elseif t_end then
				local oldrem = t_start_rem
				t_start_rem = math.ceil(t_end - sec_current)
				if t_start_rem ~= oldrem then
					net_broadcast(nil, common.net_pack("Bh",
						PKT_LTS_SET_TIMER, t_start_rem))
				end
			end
		end

		return ret
	end

	local s_create_hud = this.create_hud
	function this.create_hud(...)
		local ret = s_create_hud(...)

		local w, h
		w, h = client.screen_get_dims()
		this.round_start_text = scene.textfield{
			font=font_digits,
			text="", 
			color=0xFFFFA1A1,
			align_x=0.5, 
			align_y=0, 
			x = w/2,
			y = h-96}

		local function round_start_update(options)
			if t_start_rem then
				this.round_start_text.text = ""..t_start_rem
			else
				this.round_start_text.text = ""
			end
		end

		this.round_start_text.add_listener(GE_DELTA_TIME, round_start_update)
		this.scene.root.add_child(this.round_start_text)
		
		return ret
	end

	local s_on_disconnect = this.on_disconnect
	function this.on_disconnect(...)
		local ret = s_on_disconnect(...)
		if server then
			this.alive = false
			tally_counts()
		end
		return ret
	end

	local s_on_death = this.on_death
	function this.on_death(...)
		local ret = s_on_death(...)
		if server then
			this.alive = false
			tally_counts()
		end
		return ret
	end
	
	return this
end

