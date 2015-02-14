DIR_CHENMOD = "pkg/gm/chen/"

if client then
	mdl_player_head = model_load({
		lua={bdir=DIR_CHENMOD, name="mdl_chen_head.lua"},
	}, {"lua"})
end

local chen_padding = {
	":3", "^_^", "HONK", "MEOW", "HONK", "Yum!",
}

function chenpick(l)
	return l[math.floor(math.random()*#l)+1]
end

function chenify_msg(msg)
	local l = string.split(msg, " ")
	local i
	local maxchen = math.max(2, math.floor(math.random()*#l*0.8+1))

	local docaps = true
	for i=1,#l do
		l[i] = l[i]:lower()
		if docaps then
			l[i] = l[i]:sub(1,1):upper() .. l[i]:sub(2)
			docaps = false
		end

		if i == #l or math.random() < 0.25 then
			l[i] = l[i].."!"
			docaps = true
		end
	end
	for i=1,maxchen do
		table.insert(l, math.floor(math.random()*(#l+1)+1), chenpick(chen_padding))
	end
	table.insert(l, chenpick(chen_padding))
	return table.concat(l, " ")
end

if teams[0] then
	teams[0].name = "Chen Master Race"
	teams[0].color_mdl = {248, 0, 0}
	teams[0].color_chat = {248, 64, 32}
end

if teams[1] then
	teams[1].name = "Chen Master Race"
	teams[1].color_mdl = {248, 0, 0}
	teams[1].color_chat = {248, 64, 32}
end

if server then
	local s_pkt_offer = network.sys_tab_handlers[PKT_PLR_OFFER].f
	network.sys_tab_handlers[PKT_PLR_OFFER].f = function (neth, cli, plr, sec_current, tidx, wpn, name, pkt, ...)
		name = "Chen"
		return s_pkt_offer(neth, cli, plr, sec_current, tidx, wpn, name, pkt, ...)
	end

	local s_pkt_chat_send = network.sys_tab_handlers[PKT_CHAT_SEND].f
	network.sys_tab_handlers[PKT_CHAT_SEND].f = function (neth, cli, plr, sec_current, msg, pkt, ...)
		if msg:sub(1,1) ~= "/" then
			msg = chenify_msg(msg)
		elseif msg:sub(1,7) == "/squad " and msg ~= "/squad none" then
			msg = "/squad chen"
		end

		return s_pkt_chat_send(neth, cli, plr, sec_current, msg, pkt, ...)
	end

	local s_pkt_chat_send_team = network.sys_tab_handlers[PKT_CHAT_SEND_TEAM].f
	network.sys_tab_handlers[PKT_CHAT_SEND_TEAM].f = function (neth, cli, plr, sec_current, msg, pkt, ...)
		msg = chenify_msg(msg)
		return s_pkt_chat_send_team(neth, cli, plr, sec_current, msg, pkt, ...)
	end

	local s_pkt_chat_send_squad = network.sys_tab_handlers[PKT_CHAT_SEND_SQUAD].f
	network.sys_tab_handlers[PKT_CHAT_SEND_SQUAD].f = function (neth, cli, plr, sec_current, msg, pkt, ...)
		msg = chenify_msg(msg)
		return s_pkt_chat_send_squad(neth, cli, plr, sec_current, msg, pkt, ...)
	end
end

