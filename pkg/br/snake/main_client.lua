--[[
    This file is part of Ice Lua Components.

    Ice Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as publish3ed by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ice Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Ice Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]

dofile("pkg/base/preconf.lua")
dofile("pkg/base/lib_gui.lua")
dofile("pkg/base/lib_pmf.lua")
dofile("pkg/base/lib_sdlkey.lua")

math.randomseed(common.time())

snake = {
	xPos = 0,
	yPos = 0,
	zPos = 40,
	
	xVel = 0,
	yVel = 0,
	zVel = 0,
	
	idx = 1,
	model_bone = {},
	data = {{x=0,y=0,z=40,r=0,g=0,b=0,radius=1}},
	
	spawn = 5,
}
snake.model, snake.model_bone[1] = common.model_bone_new(common.model_new(1))
common.model_bone_set(snake.model, snake.model_bone[snake.idx], "snake", snake.data)

apple = {
	xPos = 0,
	yPos = 10,
	zPos = 30,
	
	idx = 1,
	model_bone = {},
	data = {{x=0,y=10,z=30,r=255,g=0,b=0,radius=1}},
}
apple.model, apple.model_bone[1] = common.model_bone_new(common.model_new(1))
common.model_bone_set(apple.model, apple.model_bone[apple.idx], "apple", apple.data)

box = {
	idx = 1,
	model_bone = {},
	data = {},
}
for x=-20,20,10 do
	box.data[#box.data + 1] = {x=x, y=-20, z=20, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=x, y=-20, z=60, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=x, y=20, z=20, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=x, y=20, z=60, r=255,g=255,b=255,radius=1}
end
for y=-20,20,10 do
	box.data[#box.data + 1] = {x=-20, y=y, z=20, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=-20, y=y, z=60, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=20, y=y, z=20, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=20, y=y, z=60, r=255,g=255,b=255,radius=1}
end
for z=20,60,10 do
	box.data[#box.data + 1] = {x=-20, y=-20, z=z, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=-20, y=20, z=z, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=20, y=-20, z=z, r=255,g=255,b=255,radius=1}
	box.data[#box.data + 1] = {x=20, y=20, z=z, r=255,g=255,b=255,radius=1}
end
box.model, box.model_bone[1] = common.model_bone_new(common.model_new(1))
common.model_bone_set(box.model, box.model_bone[box.idx], "box", box.data)

last_tick = nil
function client.hook_tick(sec_current, sec_delta)
	if not last_tick then
		last_tick = sec_current
	end
	while last_tick < sec_current - (0.3 - #snake.data * 0.005) do
		last_tick = last_tick + (0.3 - #snake.data * 0.005)
		input_lock = false
		snake.xPos = snake.xPos + snake.xVel
		snake.yPos = snake.yPos + snake.yVel
		snake.zPos = snake.zPos + snake.zVel
		table.remove(snake.data, 1)
		for i=1,#snake.data do
			if snake.xPos == snake.data[i].x and snake.yPos == snake.data[i].y and snake.zPos == snake.data[i].z then
				client.hook_tick = nil
				return
			end
		end
		if snake.xPos < -20 or snake.xPos > 20 or snake.yPos < -20 or snake.yPos > 20 or snake.zPos < 20 or snake.zPos > 60 then
			client.hook_tick = nil
			return
		end
		if math.abs(apple.xPos - snake.xPos) <= 2 and math.abs(apple.yPos - snake.yPos) <= 2 and math.abs(apple.zPos - snake.zPos) <= 2 then
			snake.spawn = snake.spawn + 5
			apple.xPos = math.random(40) - 20
			apple.yPos = math.random(40) - 20
			apple.zPos = math.random(40) + 20
			apple.data[#apple.data] = {
			x=apple.xPos,y=apple.yPos,z=apple.zPos,
			r=255,g=0,b=0,radius=1}
			common.model_bone_set(apple.model, apple.model_bone[apple.idx], "apple", apple.data)
		end
		snake.data[#snake.data + 1] = {
		x=snake.xPos,y=snake.yPos,z=snake.zPos,
		r=math.sin(sec_current-2*math.pi/3)*127+128,
		g=math.sin(sec_current)*127+128,
		b=math.sin(sec_current+2*math.pi/3)*127+128,
		radius=1}
		common.model_bone_set(snake.model, snake.model_bone[snake.idx], "snake", snake.data)
		if snake.spawn > 0 and (snake.xVel ~= 0 or snake.yVel ~= 0 or snake.zVel ~= 0) then
			snake.data[#snake.data + 1] = snake.data[#snake.data]
			snake.spawn = snake.spawn - 1
		end
	end
	return 0.005
end

input_lock = true
function client.hook_key(key, state)
	if state and not input_lock then
		input_lock = true
		if key == SDLK_ESCAPE then
			client.hook_tick = nil
		elseif key == SDLK_a and snake.xVel == 0 then
			snake.xVel = 2
			snake.yVel = 0
			snake.zVel = 0
		elseif key == SDLK_d and snake.xVel == 0 then
			snake.xVel = -2
			snake.yVel = 0
			snake.zVel = 0
		elseif key == SDLK_s and snake.yVel == 0 then
			snake.xVel = 0
			snake.yVel = 2
			snake.zVel = 0
		elseif key == SDLK_w and snake.yVel == 0 then
			snake.xVel = 0
			snake.yVel = -2
			snake.zVel = 0
		elseif key == SDLK_q and snake.zVel == 0 then
			snake.xVel = 0
			snake.yVel = 0
			snake.zVel = 2
		elseif key == SDLK_e and snake.zVel == 0 then
			snake.xVel = 0
			snake.yVel = 0
			snake.zVel = -2
		end
	end
end

function client.hook_render()
	client.model_render_bone_local(snake.model, snake.model_bone[snake.idx], 0,0,0,0,0,0,1)
	client.model_render_bone_local(apple.model, apple.model_bone[apple.idx], 0,0,0,0,0,0,1)
	client.model_render_bone_local(box.model, box.model_bone[box.idx], 0,0,0,0,0,0,1)
end

client.map_fog_set(32, 32, 32, 60)

print("snake client successfully loaded!")
