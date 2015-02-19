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

function glyphmap_linear(start, stop, default)
	local l = {}

	local i
	local offs = 0
	for i=start,stop do
		l[i] = offs 
		offs = offs + 1
	end

	l.gcount = (stop-start)+1
	l.default = default
	return l
end

function font_mono_new(settings)
	local this = {
		img = common.img_load(settings.fname, "png"),
		glyphmap = settings.glyphmap,
	}

	this.iwidth, this.iheight = common.img_get_dims(this.img)

	function this.render(x, y, s, c, destimg)
		c = c or 0xFFFFFFFF

		local w = this.iwidth / this.glyphmap.gcount
		local h = this.iheight

		local i
		for i=1,#s do
			local offs = this.glyphmap[s:byte(i)]
			offs = offs or this.glyphmap.default
			offs = offs or 0
			offs = offs * w

			if destimg then
				client.img_blit_to(destimg, this.img, x, y, w, h, offs, 0, c)
			else
				client.img_blit(this.img, x, y, w, h, offs, 0, c)
			end

			x = x + w
		end
	end
	
	function this.string_width(s)
		return (this.iwidth / this.glyphmap.gcount) * string.len(s)
	end
	
	function this.string_height(s)
		return this.iheight
	end

	return this
end

font_dejavu_bold = {
	[18] = font_mono_new {
		fname = "pkg/iceball/gfx/dejavu-18-bold.png",
		glyphmap = glyphmap_linear(32, 126, ("?"):byte()-32),
	},
}

