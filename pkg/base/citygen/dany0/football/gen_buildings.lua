function load_buildings()
	dofile(DIR_CITYGEN_BUILDINGS.."football/football_building.lua")
end

function manufacture_buildings(terrain_meta, map_grid)
	local mx, my, mz = common.map_get_dims()
	
	football_width = terrain_meta[1]
	football_length = terrain_meta[2]
	football_offset = terrain_meta[3]
	
	football_stadium = football_new_building({
	x = 0,
	y = my -1 - 3,
	z = football_offset,
	width = football_width,
	length = football_length,
	height = 0,
	})
	football_stadium.build()
end
