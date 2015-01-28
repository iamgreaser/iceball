--[[
Copyright (c) 2014 Team Sparkle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

-- Replace common.fetch_block.
do
	local sw, sh = client.screen_get_dims()

	-- Background loading bar
	local img_rect_bg = common.img_new(sw-10, 30)
	common.img_fill(img_rect_bg, 0xAA000000)
	do
		local i
		for i=0,sw-10-1 do
			common.img_pixel_set(img_rect_bg, i, 0, 0xAAAAAAAA)
			common.img_pixel_set(img_rect_bg, i, 30-1, 0xAAAAAAAA)
		end
		for i=0,30-1 do
			common.img_pixel_set(img_rect_bg, 0, i, 0xAAAAAAAA)
			common.img_pixel_set(img_rect_bg, sw-10-1, i, 0xAAAAAAAA)
		end
	end

	-- Foreground loading bar
	local img_rect_fg = common.img_new(sw-10-2, 30-2)
	common.img_fill(img_rect_fg, 0xFF00FF00)

	-- common.fetch_block hook
	local s_fetch_block = common.fetch_block
	function common.fetch_block(ftype, fname)
		-- Back up hooks
		local old_render = client.hook_render
		local old_tick = client.hook_tick
		local old_key = client.hook_key
		local old_mouse_button = client.hook_mouse_button
		local old_mouse_motion = client.hook_mouse_motion
		local old_map = common.map_get()
		local fr, fg, fb, fd = client.map_fog_get()

		local csize, usize, amount = 0, 0, 0

		-- Override hooks
		common.map_set(nil)
		client.map_fog_set(0, 0, 170, fd)

		function client.hook_render()
			-- Loading bar
			client.img_blit(img_rect_bg, 5, sh/2)
			if amount then
				client.img_blit(img_rect_fg, 5+1, sh/2+1, (sw-10-2)*amount)
			end

			-- Text
			local font = font_dejavu_bold and font_dejavu_bold[18]
			if font then
				local cw = font.iwidth / font.glyphmap.gcount
				local s = string.format("Loading \"%s\"", fname)
				if csize then
					s = s .. string.format(" (%i/%i, %i uncompressed)",
						(amount or 0)*csize, csize, usize)
				end
				font.render(sw/2 - cw * #s / 2, sh/2 + 4, s, 0xFFFFFFFF)
			end
		end

		function client.hook_tick(sec_current, sec_delta)
			return 1.0/60.0
		end

		function client.hook_key()
		end

		function client.hook_mouse_button()
		end

		function client.hook_mouse_motion()
		end

		-- Do the main rendering loop
		local obj = common.fetch_start(ftype, fname)

		while obj == true do
			obj, csize, usize, amount = common.fetch_poll()

			if obj == false then
				obj = true
			end
		end

		-- Restore hooks
		client.hook_render = old_render
		client.hook_tick = old_tick
		client.hook_key = old_key
		client.hook_mouse_button = old_mouse_button
		client.hook_mouse_motion = old_mouse_motion
		common.map_set(old_map)
		client.map_fog_set(fr, fg, fb, fd)

		-- Return object
		return obj
	end
end

-- Run the loader.
function client.hook_tick(sec_current, sec_delta)
	client.hook_tick = nil
	dofile(LOADER_FILE)
end

