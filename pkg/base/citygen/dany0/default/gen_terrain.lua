function gen_terrain(mx, my, mz)
	local asphalt_r, asphalt_g, asphalt_b =  12, 12, 12 -- base ground colour
	for x=0,mx-1 do
		for z=0,mz-1 do
			subtly_changing_the_colour = (1+(math.random()/10))
			l = {0, my - 4, my - 4, 0, asphalt_b*subtly_changing_the_colour, asphalt_g*subtly_changing_the_colour, asphalt_r*subtly_changing_the_colour, 1}
			if x % 8 == 0 and x % 16 ~= 0 then
				l = {0, my - 4, my - 4, 0, 120*subtly_changing_the_colour, 120*subtly_changing_the_colour, 120*subtly_changing_the_colour, 1}
			end
			common.map_pillar_set(x, z, l)
		end
	end
	
	
	for x=0,mx-1,16 do
		for z=0,mz-1 do
			if z % 4 ~= 0 then
				l = {0, my - 4, my - 4, 0, 233, 233, 233, 1}
				common.map_pillar_set(x, z, l)
			end
		end
	end
end