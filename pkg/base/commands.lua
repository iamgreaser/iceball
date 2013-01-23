function command_handle(plr, id, sockfd, params, msg)
	if params[1] == "me" then
		return "* "..plr.name.." "..string.sub(msg,5)
	elseif params[1] == "squad" then
		--TODO:
		local s = string.sub(msg,8)
		if s ~= "" then
			if s == "none" then
				plr.squad = nil
			else
				plr.squad = s
			end
			plr.update_score()
		end
	elseif params[1] == "kill" then
		plr.set_health_damage(0, 0xFF800000, plr.name.." shuffled off this mortal coil", plr)
	elseif params[1] == "goto" then
		if table.getn(params) == 2 then
			--TODO: actually do the goto
		else
			net_broadcast(nil, common.net_pack("BIz", 0x0E, usage_colour, "Usage: /goto #X ; where # is letter, X is number in the map's grid system"))
		end
	elseif params[1] == "teleport" or params[1] == "tp" then
		if table.getn(params) == 2 then
			params[2] = tostring(params[2])
			if params[2]:sub(0, 1) == "#" then
				target = players[tonumber(params[2]:sub(2))]
			end
			for i=1,players.max do
				if players[i] ~= nil and players[i].name == params[2] then
					target = players[i]
					break
				end
			end
			if target then
				x, y, z = target.x, target.y, target.z
				plr.set_pos_recv(x, y, z)
				net_broadcast(nil, common.net_pack("BBhhh",
					0x03, cli.plrid, x * 32.0, y * 32.0, z * 32.0))
			else
				net_broadcast(nil, common.net_pack("BIz", 0x0E, usage_colour, "Player not found"))
			end
		elseif table.getn(params) == 4 then
			--NOTE: I protest that y is down
			x, y, z = tonumber(params[2]), tonumber(params[3]), tonumber(params[4])
			plr.set_pos_recv(x, y, z)
			net_broadcast(nil, common.net_pack("BBhhh",
				0x03, cli.plrid, x * 32.0, y * 32.0, z * 32.0))
		else
			net_broadcast(nil, common.net_pack("BIz", 0x0E, usage_colour, "Usage: /teleport x y z ; where y is down"))
			net_broadcast(nil, common.net_pack("BIz", 0x0E, usage_colour, "Usage: /teleport player"))
		end
	end
end