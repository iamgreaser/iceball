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

PLAYER_TIMEOUT = 20

function player_new(settings)
	local this = {
		-- TODO
		neth = settings.neth or nil,
		addrinfo = settings.addrinfo or nil,
		last_msg = nil,
		last_ping = nil,
	}

	function this.disconnect()
	end

	function this.update_client(sec_current, sec_delta)
	end

	function this.update_server(sec_current, sec_delta)
		this.last_msg = this.last_msg or sec_current
		if sec_current - this.last_msg > PLAYER_TIMEOUT then
			this.disconnect()
		end
	end

	function this.update(sec_current, sec_delta)
		if server then this.update_server(sec_current, sec_delta) end
		if client then this.update_client(sec_current, sec_delta) end
	end

	return this
end

