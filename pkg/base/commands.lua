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

commands = {}
command_colour_error = 0xFFFF6666
command_colour_usage = 0xFF6666FF
command_colour_success = 0xFF66FF66
command_colour_text = 0xFFDDDDFF

function command_deregister(command)
	if commands[command] ~= nil then
		commands[command] = nil
	end
end

function command_register(settings)
	local this = {
		command = string.lower(settings.command),
		permission = settings.permission,
		usage = settings.usage,
		func = settings.func
	} this.this = this
	
	function this.exec(player, plrid, sockfd, params, msg)
		if this.permission == nil or player.has_permission(this.permission) then
			this.func(player, plrid, sockfd, params, msg)
		else
			common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Error: You do not have permission for this command"))
		end
	end
	
	commands[this.command] = this
end

--You have to deregister aliases separately
function command_register_alias(command, alias)
	commands[alias] = commands[command]
end

function command_handle(player, plrid, sockfd, params, msg)
	cmd = string.lower(params[1])
	if commands[cmd] ~= nil then
		table.remove(params, 1)
		commands[cmd].exec(player, plrid, sockfd, params, msg)
	else
		common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Error: No such command"))
	end
end

command_register({
	command = "derp",
	permission = nil,
	usage = "/derp",
	func = function(plr, plrid, sockfd, prms, msg) print "derpherp" end
})

command_register({
	command = "help",
	permission = nil,
	usage = "/help [command name]",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 0 then
			--TODO: List available commands
		elseif table.getn(prms) == 1 then
			if commands[prms[1]] == nil then
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Error: No such command"))
			elseif plr.has_permission(commands[prms[1]].permission) then
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_usage, "Usage: "..commands[prms[1]].usage))
			else
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Error: You do not have permission for this command"))
			end
		else
			this.func(plr, plrid, sockfd, "help")
		end
	end
})

command_register({
	command = "me",
	permission = "me",
	usage = "/me <action>",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) > 0 then
			net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFFFFFFFF, "* "..plr.name.." "..string.sub(msg,5)))
		else
			commands["help"].func(plr, plrid, sockfd, {"me"})
		end
	end
})

command_register({
	command = "squad",
	permission = "squad",
	usage = "/squad <squad name> (Use \"none\" to leave your squad)",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) > 0 then
			if prms[1] == "none" then
				plr.squad = nil
			else
				plr.squad = string.sub(msg,8)
			end
			plr.update_score()
		else
			commands["help"].func(plr, plrid, sockfd, {"squad"})
		end
	end
})

command_register({
	command = "kill",
	permission = "kill",
	usage = "/kill",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 0 then
			plr.set_health_damage(0, 0xFF800000, plr.name.." shuffled off this mortal coil", plr)
		else
			commands["help"].func(plr, plrid, sockfd, {"kill"})
		end
	end
})

command_register({
	command = "goto",
	permission = nil,
	usage = "/goto <grid square>",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 1 then
			--TODO: actually do the goto
		else
			commands["help"].func(plr, plrid, sockfd, {"goto"})
		end
	end
})

command_register({
	command = "teleport",
	permission = "teleport",
	usage = "/teleport <player>|<x y z>",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 1 then
			prms[1] = tostring(prms[1])
			if prms[1]:sub(0, 1) == "#" then
				target = players[tonumber(prms[1]:sub(2))]
			end
			for i=1,players.max do
				if players[i] ~= nil and players[i].name == prms[1] then
					target = players[i]
					break
				end
			end
			if target then
				x, y, z = target.x, target.y, target.z
				plr.set_pos_recv(x, y, z)
				net_broadcast(nil, common.net_pack("BBhhh",
					0x03, plrid, x * 32.0, y * 32.0, z * 32.0))
			else
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Error: Player not found"))
			end
		elseif table.getn(prms) == 3 then
			--NOTE: I protest that y is down/same way AoS was
			x, y, z = tonumber(prms[1]), tonumber(prms[2]), tonumber(prms[3])
			plr.set_pos_recv(x, y, z)
			net_broadcast(nil, common.net_pack("BBhhh",
				0x03, plrid, x * 32.0, y * 32.0, z * 32.0))
		else
			commands["help"].func(plr, plrid, sockfd, {"teleport"})
		end
	end
})
command_register_alias("teleport", "tp")

command_register({
	command = "goto",
	permission = "goto",
	usage = "/goto #X ; where # is letter, X is number in the map's grid system",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 1 then
			prms[1] = tostring(prms[1])
			local x, z
			local success = pcall(function()
				x = (string.byte(prms[1]:lower()) - 97) * 64
				z = (tonumber(prms[1]:sub(2, 2)) - 1) * 64
			end)
			local xlen, _, zlen = common.map_get_dims()
			if (success and x >= 0 and x < xlen and z >= 0 and z < zlen) then
				local y = common.map_pillar_get(x, z)[1+1]
				plr.set_pos_recv(x, y, z)
				net_broadcast(nil, common.net_pack("BBhhh",
					0x03, plrid, x * 32.0, y * 32.0, z * 32.0))
			else
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Error: Invalid coordinates"))
			end
		else
			commands["help"].func(plr, plrid, sockfd, {"goto"})
		end
	end
})

command_register({
	command = "intel",
	permission = "intel",
	usage = "/intel",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 0 then
			local i
			for i=1,#intent do
				if intent[i] ~= nil then
					common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_text, teams[intent[i].team].name..": "..intent[i].x..", "..intent[i].y..", "..intent[i].z))
				end
			end
		else
			commands["help"].func(plr, plrid, sockfd, {"intel"})
		end
	end
})

command_register({
	command = "login",
	permission = nil,
	usage = "/login <group> <password>",
	func = function(plr, plrid, sockfd, prms, msg)
		if table.getn(prms) == 2 then
			local success = false
			if permissions[prms[1]] ~= nil and prms[2] == permissions[prms[1]].password then
				-- Should logging in change permissions or add to them? Should you be able to log out?
				plr.permissions = permissions[prms[1]].perms
				success = true
			end
			if success then
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_success, "You have successfully logged in as "..prms[1]))
			else
				common.net_send(sockfd, common.net_pack("BIz", 0x0E, command_colour_error, "Could not log in to group"..prms[1].." with that password"))
			end
		else
			commands["help"].func(plr, plrid, sockfd, {"login"})
		end
	end
})