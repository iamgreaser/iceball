hitler_death_toll = 0
do
	local s_fastload_fetch = fastload_fetch
	local s_load_screen_fetch = nil
	local hitler_widget = nil

	function hitler_append_draw()
		local s_hook_render = client.hook_render
		function client.hook_render(...)
			local ret = s_hook_render(...)
			local mHi = hitler_death_toll/6
			local s = string.format("Death toll: %0.3f microhitlers", mHi)
			font_mini.print(screen_width-2-((#s)*6), 2, 0xFFFFFFFF, s)
			return ret
		end
	end
	function fastload_fetch(...)
		if not s_load_screen_fetch then
			-- Catch first packet sent on client
			if client then
				local pkt, neth = common.net_recv()
				if pkt ~= nil and #pkt >= 4 then
					hitler_death_toll, pkt = common.net_unpack("I", pkt)
				else
					error("should have received a death toll by now!")
				end
			end

			s_load_screen_fetch = load_screen_fetch
			function load_screen_fetch(...)
				local s_fetch_poll = common.fetch_poll
				function common.fetch_poll(...)
					hitler_append_draw()
					common.fetch_poll = s_fetch_poll
					return s_fetch_poll(...)
				end
				local obj = s_load_screen_fetch(...)
				common.fetch_poll = s_fetch_poll
				return obj
			end
			common.fetch_block = load_screen_fetch
		end
		return s_fastload_fetch(...)
	end
end

