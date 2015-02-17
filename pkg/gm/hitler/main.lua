
if server then
	local s_hook_connect = server.hook_connect
	function server.hook_connect(neth, ...)
		print("sending hitler death toll:", hitler_death_toll)
		common.net_send(neth, common.net_pack("I", hitler_death_toll))
		return s_hook_connect(neth, ...)
	end

	local s_new_player = new_player
	function new_player(...)
		local this = s_new_player(...)

		local s_on_death = this.on_death
		function this.on_death(...)
			hitler_death_toll = hitler_death_toll + 1
			return s_on_death(...)
		end

		return this
	end
end

