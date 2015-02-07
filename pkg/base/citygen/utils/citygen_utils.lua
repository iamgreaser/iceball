
--subtly sweeten up block colour with a little bit of noise
--only solid blocks have colour anyway so dropping the type param
function map_block_set_randc(x, y, z, r, g, b)
	rand = 1+(math.random()/11) --todo: param to control noise amount
	map_block_set(x, y, z, 1,
					math.max(math.min(r*rand, 255), 0),
					math.max(math.min(g*rand, 255), 0),
					math.max(math.min(b*rand, 255), 0))
end

--TODO: deprecate these
function randint(x, y)
	return x+math.floor(tonumber(math.random()*(y-x)))
end

function choice(array)
	return array[math.random(#array)]
end