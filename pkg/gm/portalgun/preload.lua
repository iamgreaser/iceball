do
	local s_dofile = dofile
	function dofile(fname)
		s_dofile(fname)
		if fname == "pkg/base/common.lua" then
			-- can't grab libs via dofile, so use the next dofile on the list
			dofile("pkg/gm/portalgun/hook_player.lua")
			dofile("pkg/gm/portalgun/hook_map.lua")
		end
	end
end

