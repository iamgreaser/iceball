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

---
-- Create a new event manager object.
-- @return event_manager instance
function event_manager()
	local this = {}
	
	-- Lets have some room to breathe
	this.ORDER_EARLIER = 0
	this.ORDER_EARLY = 10
	this.ORDER_DEFAULT = 20
	this.ORDER_LATE = 30
	this.ORDER_LATER = 40
	this.ORDER_MONITOR = 100
	
	local handlers = {}
	
	local function sort_handlers(one, two)
		return one.order < two.order
	end
	
	---
	-- Register a new event handler.
	-- @param event_type Event type name to be handled
	-- @param handler Function with parameters (event_type, event_data)
	-- @param order One of ORDER_* to determine the position in the list of handlers
	-- @param cancelled Whether or not to received cancelled events
	function this.register(event_type, handler, order, cancelled)
		cancelled = cancelled or false
		order = order or this.ORDER_DEFAULT
		
		if handlers[event_type] == nil then
			handlers[event_type] = {}
		end
		
		local event_handlers = handlers[event_type]
		event_handlers[#event_handlers + 1] = {
			handler = handler,
			order = order,
			cancelled = cancelled
		}
		table.sort(event_handlers, sort_handlers)
	end
	
	---
	-- Deregister a previously registered handler.
	-- @param event_type Event type name previously registered
	-- @param handler Function previously registered
	function this.deregister(event_type, handler)
		if handlers[event_type] == nil then
			return
		end
		
		local event_handlers = handlers[event_type]
		for i=#event_handlers,1,-1 do
			if event_handlers[i].handler == handler then
				table.remove(event_handlers, i)
			end
		end
		table.sort(event_handlers, sort_handlers)
	end
	
	---
	-- Fire an event.
	-- Event data can contain a "cancelled" attribute.
	-- @param event_type Event type name to be handled
	-- @param data Event data table
	-- @return data is returned for convenience
	function this.fire(event_type, data)
		if data.cancelled == nil then
			data.cancelled = false
		end
		
		local event_handlers = handlers[event_type]
		
		if event_handlers == nil then
			return data
		end
		
		for i, handler in ipairs(event_handlers) do
			if handler.cancelled or not data.cancelled then
				handler.handler(event_type, data)
			end
		end
		
		return data
	end
	
	return this
end

events = event_manager()

function derp(t, d)
	print("HANDLER1! "..t)
	print(d)
end

function herp(t, d)
	print("HANDLER2! "..t)
	print(d)
end

events.register("derp", derp, events.ORDER_DEFAULT)
events.register("derp", herp, events.ORDER_DEFAULT, true)

data = {cancelled=true}
events.fire("derp", data)