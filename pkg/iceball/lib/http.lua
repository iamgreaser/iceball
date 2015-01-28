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

function url_parse(url)
	local colon, slash
	local proto, host, port

	-- Work out the protocol.
	colon = url:find(":")
	if not colon then return end
	proto = url:sub(1,colon-1)
	url = url:sub(colon+1)
	
	-- We only handle so many (or should I say "few") protocols.
	if proto == "http" then
		-- Get that // bit.
		if url:sub(1,2) ~= "//" then
			print("expected \"//\" after \":\"")
			return
		end
		url = url:sub(3)

		-- If there is a : before a /, there's a port to read.
		colon = url:find(":")
		slash = url:find("/")

		-- FIXME: This step probably throws a Lua error if it's not a numeric.
		if colon and ((not slash) or slash > colon) then
			host = url:sub(1, colon-1)
			local portstr = url:sub(colon+1, (slash and slash-1))
			port = 0 + portstr
		else
			host = url:sub(1, (slash and slash-1))
			port = 80
		end

		-- Include the / in the URL.
		if slash then
			url = url:sub(slash)
		else
			url = "/"
		end

		-- Return all the details.
		return proto, host, port, url
	else
		print("unknown protocol \""..proto.."\"")
		return
	end

end

--print(url_parse("http://iceball.rakiru.com:27790/master.json"))

function http_new(settings)
	local this = {
		url = settings.url,
		method = settings.method or "GET",
		state = "send",
		recv_state = "head",
		req_code = nil,
		req_len = nil,
		data = nil,
	}

	function this.read_header(s)
		if s == "" then
			-- FIXME: validate the state BEFORE we actually move
			this.recv_state = "body"
		elseif not this.req_code then
			-- FIXME: parse this properly
			local http_ver = s:sub(1, s:find(" ")-1)
			s = s:sub(s:find(" ")+1)
			this.req_code = 0 + s:sub(1, s:find(" ")-1)
		else
			local fieldpos = s:find(":")
			local name = s:sub(1, fieldpos-1)
			local field = s:sub(fieldpos+2)
			print("["..name.."|"..field.."]")

			if name == "Length" then
				-- FIXME: This can cause a Lua error if not a number
				this.req_len = 0 + field
			end
		end
	end

	function this.parse_stuff()
		if this.recv_state == "head" then
			-- Read headers
			while this.recv_state == "head" do
				local pos = this.data:find("\r\n")
				if not pos then break end

				this.read_header(this.data:sub(1,pos-1))
				this.data = this.data:sub(pos+2)
			end
		end

		-- This can always move from head to body in one packet.
		if this.recv_state == "body" then
			if this.data and #(this.data) >= this.req_len then
				this.data = this.data:sub(1,this.req_len)
				this.close()
				this.state = "pass"
				return this.data
			end
		end

		return true
	end

	function this.finalise()
		this.close()
		this.state = ((this.recv_state == "body" and this.data) and "pass") or "fail"
		return (this.recv_state == "body" and this.data)
	end

	function this.update()
		if this.state == "send" then
			this.rq = common.tcp_send(this.sockfd, this.rq)
			if not this.rq then
				this.fail()
			elseif this.rq == "" then
				this.state = "recv"
			end
		elseif this.state == "recv" then
			local d = common.tcp_recv(this.sockfd)
			if not d then
				return this.finalise()
			end

			this.data = (this.data or "") .. d
			return this.parse_stuff()
		elseif this.state == "fail" then
			return nil
		elseif this.state == "pass" then
			return this.data
		end

		return true
	end

	function this.close()
		if this.sockfd then
			common.tcp_close(this.sockfd)
			this.sockfd = nil
		end
	end

	function this.fail()
		this.close()
		this.state = "fail"
	end

	function this.init()
		-- Parse the URL.
		local rq = ""
		local proto, host, port, root = url_parse(this.url)
		if proto ~= "http" then
			print("http requests require the http protocol to be used")
			return
		end

		-- Set up the request.
		-- TODO: Sanitise the URLs so they don't have spaces
		rq = rq .. "GET " .. root .. " HTTP/1.1\r\n"
		rq = rq .. "Host: ".. host .."\r\n"
		rq = rq .. "Accept: */*\r\n"
		rq = rq .. "User-Agent: IceballQuery/1.0\r\n"
		rq = rq .. "\r\n"

		-- Begin the fetch now.
		-- FIXME: This can throw an error in some weird cases, apparently.
		this.sockfd = common.tcp_connect(host, port)
		if not this.sockfd then
			print("connection failed")
			return
		end
		this.rq = rq

		-- Return this object.
		return this
	end

	return this.init()
end

