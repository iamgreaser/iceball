PKT_EXEC = network.sys_alloc_packet()

network.sys_handle_common(PKT_EXEC, "z", function (neth, cli, plr, sec_current, line, pkt)
	local a,b
	a,b = pcall(function () loadstring(line)() end)
	if not a then
		print("quickcall err:", b)
	end
end)

