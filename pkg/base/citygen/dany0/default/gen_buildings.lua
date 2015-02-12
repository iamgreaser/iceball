function load_buildings()
	dofile(DIR_CITYGEN_BUILDINGS.."/basic_building.lua")
end

-- function create_city_grid()
	-- local mx, my, mz = common.map_get_dims()
	-- we're just doing a basic "procedural" generation, but if you want
	-- use this to set building x,y,z and build roads
	-- then call manufacture_buildings() to build the buildings
-- end

function manufacture_buildings()
	local mx, my, mz = common.map_get_dims()
	
	local building_number = math.floor((mx-24)/12)
	for i=1+12, mx-1-12, 1*(12+16) do
		print("- building section "..i)
		map_cache_start() -- cache here instead of outside the loop to save on RAM
		for y=1+12, mz-1-12, 1*(12+16) do
			rand_height = math.floor(13 + math.random()*37)
			building = new_building({})
			building.build_at(i + 12, my-4-rand_height, y+12, 12, 12, rand_height)
		end
		map_cache_end()
	end
end