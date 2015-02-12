function gen_terrain(mx, my, mz)

	football_width = mx --math.max(mx, mz)
	football_length = math.floor(football_width/1.544) + 1 -- associaton rules football ratio
	for x=0,mx-1 do
		for z=0,mz-1 do
			subtly_changing_the_colour = (1+(math.random()/10))
			common.map_pillar_set(x, z, {0, my-1-1, my-1-1, 0,
				math.min(234 * subtly_changing_the_colour, 255), math.min(24 * subtly_changing_the_colour, 255), math.min(24 * subtly_changing_the_colour, 255),
			1})
		end
	end
	
	football_offset = (mz-football_length)/2
	for x=0,football_width-1 do
		for z=football_offset,mz-1-football_offset do
			subtly_changing_the_colour = (1+(math.random()/10))
			common.map_pillar_set(x, z, {0, my-1-2, my-1-2, 0,
				math.min(24 * subtly_changing_the_colour, 255), math.min(24 * subtly_changing_the_colour, 255), math.min(24 * subtly_changing_the_colour, 255),
			1})
		end
	end
	
	return {football_width, football_length, football_offset}
end