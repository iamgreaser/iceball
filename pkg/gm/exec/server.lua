PKT_EXEC = network.sys_alloc_packet()

command_register({
	command = "x",
	permission = "ban", -- TODO give own permission
	usage = "/x *(all)|!(server)|~(you)|#player(other) lua_code_goes_here",
	func = (function(plr, plrid, neth, prms, msg)
		local line = string.sub(msg, (msg:find(" ", 4, true) or msg:len()-1)+1)
		local tgt = string.sub(msg, 4, (msg:find(" ", 4, true) or msg:len()+1)-1)
		print ("["..tgt.."]: {"..line.."}")
		if tgt == "!" then
			local a,b
			a,b = pcall(function () loadstring(line)() end)
			if not a then
				print("Exec Error: "..b)
				common.net_send(neth, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, command_colour_error, "Error: "..b))
			end
		elseif tgt == "~" then
			common.net_send(neth, common.net_pack("Bz", PKT_EXEC, line))
		elseif tgt == "*" then
			net_broadcast(nil, common.net_pack("Bz", PKT_EXEC, line))
		else
			tgt = tostring(tgt)
			if tgt:sub(0, 1) == "#" then
				target = players[tonumber(tgt:sub(2))]
			end
			for i=1,players.max do
				if players[i] ~= nil and players[i].name == tgt then
					target = players[i]
					break
				end
			end
			if target then
				common.net_send(neth, common.net_pack("Bz", PKT_EXEC, line))
			else
				common.net_send(neth, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, command_colour_error, "Error: Player not found"))
			end
		end
	end)
})

