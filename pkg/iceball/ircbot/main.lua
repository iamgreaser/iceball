--[[
    This file is part of Ice Lua Components.

    Ice Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ice Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Ice Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
IMPORTANT NOTE FROM RFC 1459:

IRC messages are always lines of characters terminated with a CR-LF
(Carriage Return - Line Feed) pair, and these messages shall not
exceed 512 characters in length, counting all characters including
the trailing CR-LF. Thus, there are 510 characters maximum allowed
for the command and its parameters.  There is no provision for
continuation message lines.
]]

irc = {}
irc.conns = {}

function ircbot_conn_new(settings)
	local this = {}

	this.addr = settings.addr or error("IRC bot address not set!")
	this.port = settings.port or 6667
	this.nick = settings.nick or "iceball"
	this.user = settings.user or "iceball"
	this.rname = settings.rname or "Iceball Server Bot"
	this.channel = settings.channel or error("IRC bot channel not set!")
	this.chat_prefix = settings.chat_prefix or "."
	this.cmd_prefix = settings.cmd_prefix or "!"
	this.chat_color = settings.chat_color or 0xFFFFAAFF

	this.working = false
	this.sockfd = nil
	this.recvq = ""
	this.sendq = ""
	this.can_write = false
	this.in_server = false
	this.in_channel = false

	function this.connect()
		this.sockfd = common.tcp_connect(this.addr, this.port)
		if this.sockfd == nil then
			this.working = false
			return false
		end

		this.working = true
		this.sendq = this.sendq .. (
			"USER"..
			" "..this.user..
			" ".."*"..
			" ".."*"..
			" :"..this.rname..
			"\r\n")
		this.sendq = this.sendq .. (
			"NICK"..
			" "..this.nick..
			"\r\n")

		return true
	end

	function this.write(msg)
		if not this.working then return false end
		if not this.can_write then return false end

		-- TODO: SANITISE!
		this.sendq = this.sendq .. (
			"PRIVMSG"..
			" "..this.channel..
			" :"..msg..
			"\r\n")
	end

	function this.handle_msg(sec_current, sec_delta, m)
		if m.cmd == "PING" then
			this.sendq = this.sendq .. (
				"PONG"..
				" :"..m.params[1]..
				"\r\n")

		elseif not this.in_server then
			if m.cmd == "001" then
				print("IRC bot entered server")
				this.in_server = true
				this.sendq = this.sendq .. (
					"JOIN"..
					" "..this.channel..
					"\r\n")

			end
		elseif not this.in_channel then
			if m.cmd == "JOIN" then
				if m.params[1]:lower() == this.channel:lower() then
					print("IRC bot entered channel")
					this.in_channel = true
					this.can_write = true
					--this.write("channel join test")
				else
					print("IRC bot was force joined to a different channel")
					this.sendq = this.sendq .. (
						"PART"..
						" "..m.params[1]..
						" :".."not assigned to this channel"..
						"\r\n")
				end

			end
		elseif m.cmd == "353" then
			-- RPL_NAMREPLY
			-- TODO: parse oper status and whatnot
			-- TODO: track nicks
		elseif m.cmd == "PRIVMSG" then
			print("privmsg: ("..m.params[1]..") <"..m.nick.."> "..m.params[2])
			if m.params[1]:lower() == this.channel:lower() then
				local msg = m.params[2]
				if msg:sub(1,this.chat_prefix:len()) == this.chat_prefix then
					local rmsg = msg:sub(this.chat_prefix:len()+1)
					net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT,
						this.chat_color, "<"..m.nick.."> "..rmsg))
				elseif msg:sub(1,this.cmd_prefix:len()) == this.cmd_prefix then
					-- TODO: parse commands
				end
			end
		end
	end

	function this.update(sec_current, sec_delta, ...)
		-- Cut off if connection broken
		if not this.working then return false end

		-- Send what we can
		if this.sendq ~= "" then
			local s = common.tcp_send(this.sockfd, this.sendq)
			if s == false then
				print("CANNOT SEND, ERROR OCCURRED")
				this.working = false
				common.tcp_close(this.sockfd)
				this.sockfd = nil
				return false
			end
			this.sendq = s
		end

		-- Receive what we can
		local r = common.tcp_recv(this.sockfd)
		if r == false then
			print("CANNOT RECV, ERROR OCCURRED")
			this.working = false
			common.tcp_close(this.sockfd)
			this.sockfd = nil
			return false
		end
		this.recvq = this.recvq .. r

		-- Parse recvq
		while true do
			local idx = this.recvq:find("\r\n")
			if idx == nil then break end
			local s = this.recvq:sub(1, idx-1)
			this.recvq = this.recvq:sub(idx+2)

			-- Hostmask
			local mmask = nil
			local mnick = nil
			local muser = nil
			local mhost = nil
			if s:sub(1,1) == ":" then
				-- Separate hostmask from message
				idx = s:find(" ")
				if not idx then
					-- Shouldn't happen, but keep this robust anyway
					mmask = s:sub(2)
					s = ""
				else
					mmask = s:sub(2, idx-1)
					s = s:sub(idx+1)
				end

				-- Split hostmask
				local ts = mmask
				idx = ts:find("@")
				if idx then
					mhost = ts:sub(idx+1)
					ts = ts:sub(1, idx-1)
				end
				idx = ts:find("!")
				if idx then
					muser = ts:sub(idx+1)
					ts = ts:sub(1, idx-1)
				end
				mnick = ts
			end

			-- Command
			idx = s:find(" ")
			local cmd = (idx and s:sub(1, idx-1)) or s
			s = (idx and s:sub(idx+1))

			local params = {}

			while s do
				if s:sub(1,1) == ":" then
					s = s:sub(2)
					params[1+#params] = s
					s = nil
				else
					idx = s:find(" ")
					params[1+#params] = (idx and s:sub(1, idx-1)) or s
					s = (idx and s:sub(idx+1))
				end
			end

			s = ""
			local i
			for i = 1,#params do
				s = s .. " {" .. params[i] .. "}"
			end

			print("IRC:", mmask, mnick, muser, mhost, cmd, s)

			this.handle_msg(sec_current, sec_delta, {
				mask = mmask,
				nick = mnick,
				user = muser,
				host = mhost,
				cmd = cmd,
				params = params,
			})
		end

		return true
	end

	if this.connect() then
		irc.conns[1+#(irc.conns)] = this
	end
end

function irc.connect(settings)
	ircbot_conn_new(settings)
end

function irc.update(sec_current, sec_delta, ...)
	local k,v
	for k,v in pairs(irc.conns) do
		v.update(sec_current, sec_delta, ...)
	end
end

function irc.write(msg)
	local k,v
	for k,v in pairs(irc.conns) do
		v.write(msg)
	end
end

