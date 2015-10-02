PKT_PORTALGUN_SET = network.sys_alloc_packet()

DIR_PORTALGUN = "pkg/gm/portalgun/"

WPN_PORTALGUN = weapon_add(DIR_PORTALGUN.."/gun_portal.lua")
weapons_enabled[WPN_PORTALGUN] = true

network.sys_handle_c2s(PKT_PORTALGUN_SET, "BBhhhbbbbbb", nwdec_plrset(
		function (neth, cli, plr, sec_current, pid,
		portal_select, cx, cy, cz, dx, dy, dz, sx, sy, sz)
	print("RECEIVED")
	if not (plr and plr.has_permission("build")) then return end
	print("Got player")

	if portal_select ~= 1 and portal_select ~= 2 then return end
	print("Got valid portal")

	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	if not (cx >= 0 and cx < xlen and cz >= 0 and cz < zlen and cy >= 0 and cy < ylen) then return end
	print("Got valid coords")

	if dx == 0 and dy == 0 and dz == 0 then
		print("SERVER DELETE PORTAL "..portal_select)
		plr.portal_list[portal_select] = nil
		net_broadcast(nil, common.net_pack("BBBhhhbbbbbb",
			PKT_PORTALGUN_SET, cli.plrid, portal_select,
			cx, cy, cz, dx, dy, dz, sx, sy, sz))
	else
		print("SERVER CREATE PORTAL "..portal_select.." AT ("..cx..", "..cy..", "..cz..")")
		plr.portal_list[portal_select] = {cx, cy, cz, dx, dy, dz, sx, sy, sz}
		net_broadcast(nil, common.net_pack("BBBhhhbbbbbb",
			PKT_PORTALGUN_SET, cli.plrid, portal_select,
			cx, cy, cz, dx, dy, dz, sx, sy, sz))
	end
end))

network.sys_handle_s2c(PKT_PORTALGUN_SET, "BBhhhbbbbbb", 
		function (neth, cli, plr, sec_current, pid,
		portal_select, cx, cy, cz, dx, dy, dz, sx, sy, sz)

	print("CLIENT RECEIVED", pid)
	local plr = players[pid]
	if not plr then return end
	print("Got player")

	if portal_select ~= 1 and portal_select ~= 2 then return end
	print("Got valid portal")

	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	if not (cx >= 0 and cx < xlen and cz >= 0 and cz < zlen and cy >= 0 and cy < ylen) then return end
	print("Got valid coords")

	if dx == 0 and dy == 0 and dz == 0 then
		print("CLIENT DELETE PORTAL "..pid..":"..portal_select)
		plr.portal_list[portal_select] = nil
		if plr.portal_list[3-portal_select] then
			plr.portal_list[3-portal_select].va = nil
		end
	else
		print("CLIENT CREATE PORTAL "..pid..":"..portal_select.." AT ("..cx..", "..cy..", "..cz..")")
		plr.portal_list[portal_select] = {cx, cy, cz, dx, dy, dz, sx, sy, sz}
		if plr.portal_list[3-portal_select] then
			plr.portal_list[3-portal_select].va = nil
		end
	end
end)

if server then
	-- TODO more elegant method
	local s_slot_add = slot_add
	function slot_add(neth, tidx, wpn, name, ...)
		wpn = WPN_PORTALGUN
		return s_slot_add(neth, tidx, wpn, name, ...)
	end
end

