local rt_scale = 4
local rt_sweepdist = 10
local fbo_rt = client.fbo_create(screen_width/rt_scale, screen_height/rt_scale, true)
local shader_rt_map, result = shader_new{name="rt_map", vert=[=[

varying vec3 camh_in;
varying vec3 camv_in;
varying vec3 wpos_in;
varying vec3 wdir_in;
varying vec3 cdir_in;
varying vec3 dvec_in;

void main()
{
	float vw = (gl_ProjectionMatrix*vec4(1.0, 0.0, 0.0, 0.0)).x;
	float vh = (gl_ProjectionMatrix*vec4(0.0, 1.0, 0.0, 0.0)).y;
	vec2 vmul = vec2(-1.0/vw, -1.0/vh);
	wpos_in = (gl_ModelViewMatrixInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	wdir_in = (gl_ModelViewMatrixInverse * vec4(-gl_Vertex.xy*vmul, 1.0, 0.0)).xyz;
	dvec_in = gl_Vertex.xyz;
	camh_in = normalize((gl_ModelViewMatrixInverse * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	camv_in = normalize((gl_ModelViewMatrixInverse * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	cdir_in = normalize((gl_ModelViewMatrixInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	gl_Position = vec4(gl_Vertex.x, gl_Vertex.y, -0.1, 1.0);
	gl_FrontColor = gl_Color;
}

]=], frag=common.bin_load("pkg/gm/rt/shader_map.frag")}

assert(shader_rt_map, result)

local shader_rt_img, result = shader_new{name="rt_img", vert=[=[

varying vec2 tc_in;

void main()
{
	tc_in = (gl_Vertex.xy+1.0)/2.0;
	gl_Position = vec4(gl_Vertex.x, gl_Vertex.y, -0.1, 1.0);
	gl_FrontColor = gl_Color;
}

]=], frag=[=[

uniform sampler2D tex0;
uniform float tex0_scale;
uniform vec2 screen_siz;
uniform vec2 screen_isiz;
varying vec2 tc_in;

void main()
{
	//vec2 tc = floor(tc_in * screen_siz + 0.1);
	vec2 tc = (floor(tc_in * screen_siz + 0.1) + 0.1) * screen_isiz;
	/*
	vec2 tcq = floor(tc/tex0_scale)*tex0_scale;
	vec2 tcr = tc - tcq;
	tcq += 0.5;
	tc += 0.5;
	*/

	// Apply blur
	// TODO: get a real kernel
	vec4 cc = texture2D(tex0, tc);
	/*
	vec4 cb1 = (vec4(0.0)
		+ texture2D(tex0, tc + vec2( 1.0, 0.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2( 0.0, 1.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2(-1.0, 0.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2( 0.0,-1.0)*tex0_scale*screen_isiz)
	);
	vec4 cb2 = (vec4(0.0)
		+ texture2D(tex0, tc + vec2( 1.0, 1.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2( 1.0,-1.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2(-1.0, 1.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2(-1.0,-1.0)*tex0_scale*screen_isiz)
	);
	vec4 cb3 = (vec4(0.0)
		+ texture2D(tex0, tc + vec2( 2.0, 0.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2( 0.0, 2.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2(-2.0, 0.0)*tex0_scale*screen_isiz)
		+ texture2D(tex0, tc + vec2( 0.0,-2.0)*tex0_scale*screen_isiz)
	);
	*/

	vec4 cfinal = cc;

	/*
	if(cc.a > 0.66)
	{
		cfinal = mix((cc + cb1)/5.0, cc, cc.a);
	} else if(cc.a > 0.33) {
		cfinal = mix(mix((cc + cb1)/5.0, cc, cc.a), (cc + cb1 + cb2)/9.0, cc.a/0.66);
	} else {
		cfinal = mix(
			mix(mix((cc + cb1)/5.0, cc, cc.a), (cc + cb1 + cb2)/9.0, cc.a/0.66)
			, (cc + cb1 + cb2 + cb3)/13.0, cc.a/0.33);
	}
	*/

	gl_FragColor = vec4(cfinal.rgb, 1.0);
}
]=]}
assert(shader_rt_img, result)

client.map_set_render_format(map_loaded, "3v,3c")
local rt_force_update_full = true
local rt_tex = nil
local rt_hmap = {}

local function rt_update_map_height(pz)
	local x
	local xlen, ylen, zlen = common.map_get_dims()

	rt_hmap[pz+1] = rt_hmap[pz+1] or {}

	for x=0,xlen-1 do
		rt_hmap[pz+1][x+1] = common.map_pillar_get(x, pz)[2]
	end
end

local function rt_update_map_ring(px, pz)
	local i, j
	local rs = 0

	px = px + 1
	pz = pz + 1
	local py = rt_hmap[pz][px]

	for i=1,rt_sweepdist do
		for j=-i,i do
			local x0, z0 = px-i+j, pz-i
			local x1, z1 = px+i, pz+i+j
			local x2, z2 = px+i-j, pz+i
			local x3, z3 = px-i, pz-i-j

			local y0 = (rt_hmap[z0] and rt_hmap[z0][x0]) or py
			local y1 = (rt_hmap[z1] and rt_hmap[z1][x1]) or py
			local y2 = (rt_hmap[z2] and rt_hmap[z2][x2]) or py
			local y3 = (rt_hmap[z3] and rt_hmap[z3][x3]) or py

			if y0 < py then return rs end
			if y1 < py then return rs end
			if y2 < py then return rs end
			if y3 < py then return rs end
		end

		rs = i
	end

	return rs
end

local function rt_gap_count(l)
	local i = 1
	local c = 1

	while l[i] ~= 0 do
		i = i + 4*l[i]
		c = c + 1
	end

	return c + (#l)/4
end

local function rt_update_map_z(pz, do_sweep)
	local xlen, ylen, zlen = common.map_get_dims()
	local xoffs0 = xlen
	local xoffs1 = xlen
	local x, y, z
	z = pz

	local function skip_to_y(px, pz, ty)
		if ty == 0 then return 0 end
		if px < 0 or pz < 0 or px >= xlen or pz >= zlen then return 0 end

		local l = common.map_pillar_get(px, pz)
		local i = 0
		local iadd = 0

		while true do
			if l[i+1] == 0 then break end
			if ty <= l[i+3] then break end
			i = i + l[i+1]*4
			iadd = iadd + 1
		end

		return math.floor(i/4) + iadd
	end

	for x=0,xlen-1 do
		local l = common.map_pillar_get(x, z)
		local xoffs, zoffs

		if xoffs0 <= xoffs1 then
			xoffs = xoffs0
			zoffs = 0
		else
			xoffs = xoffs1
			zoffs = 1
		end

		do
			local sx, sz
			sx = x
			sz = z
			if sz >= 0 and sz < zlen then
				local pdata = xoffs + 1 + (zoffs*0x010000)
				common.img_pixel_set(rt_tex, sx, sz, pdata
					+ ((do_sweep and 0x01000000*rt_update_map_ring(sx, sz)) or 0))
			end
		end

		--common.img_pixel_set(rt_tex, xoffs, z*2 + zoffs, 0)
		local time_to_gap = 0
		for y=0,#l-1,4 do
			assert(xoffs < rt_xsi)
			local ninc = 0
			if time_to_gap == 0 then
				-- Calculate accel structure
				local ty = (y == 0 and 0) or l[y+4]
				common.img_pixel_set(rt_tex, xoffs, z*2 + zoffs,
					0
					+ skip_to_y(x-1, z, ty)*0x00010000
					+ skip_to_y(x+1, z, ty)*0x00000100
					+ skip_to_y(x, z-1, ty)*0x00000001
					+ skip_to_y(x, z+1, ty)*0x01000000
					)

				-- Advance
				time_to_gap = l[y+1]
				xoffs = xoffs + 1
				ninc = 1
			end

			time_to_gap = time_to_gap - 1

			common.img_pixel_set(rt_tex, xoffs, z*2 + zoffs,
				0
				+ (l[y+1]+ninc)*0x00000001
				+ (l[y+2])*0x00000100
				+ (l[y+3])*0x00010000
				+ (l[y+4])*0x01000000
			)
			xoffs = xoffs + 1
		end

		if zoffs == 0 then
			xoffs0 = xoffs
		else
			xoffs1 = xoffs
		end
	end
end

local function rt_update_map_full()
	-- Get map dims
	local x, y, z
	local _, xsi, zsi, xlen, zlen
	local map = common.map_get()
	xlen, _, zlen = common.map_get_dims()
	rt_xsi, rt_zsi = xlen, xlen*2

	-- Get map data size
	local xmax = 0
	for z=0,zlen-1 do
		local xsum0 = 0
		local xsum1 = 0

		for x=0,xlen-1 do
			if xsum0 <= xsum1 then
				xsum0 = xsum0 + rt_gap_count(common.map_pillar_get(x, z))
			else
				xsum1 = xsum1 + rt_gap_count(common.map_pillar_get(x, z))
			end
		end

		local xsum = math.max(xsum0, xsum1)

		xmax = math.max(xmax, xsum)
	end

	while rt_xsi < xmax+xlen+256 do -- allow extra space
		rt_xsi = rt_xsi * 2
	end
	print("xmax:", xmax, xmax+xlen, rt_xsi)

	-- Create texture
	rt_tex = common.img_new(rt_xsi, rt_zsi)

	-- Copy data to GPU
	for z=0,zlen-1 do
		rt_update_map_height(z)
	end
	for z=0,zlen-1 do
		rt_update_map_z(z, true)
		print((z+1)*100/zlen)
	end

	-- Force image commit
	--client.img_blit(rt_tex, 0, 0)

	-- TODO: make this work
	rt_force_update_full = false
end

local function rt_update_map_check(px, pz, ol, nl)
	if rt_force_update_full then
		return rt_update_map_full()
	end

	local i
	local same = false and (#nl == #ol) -- TODO: use this optimisation

	if same then
		for i=1,#ol do
			if ol[i] ~= nl[i] then
				same = false
				break
			end
		end
	end

	if same then return end

	local xlen, ylen, zlen = common.map_get_dims()
	rt_update_map_height(pz)

	if pz-1 >= 0 then rt_update_map_z(pz-1, false) end
	rt_update_map_z(pz, false)
	if pz+1 < zlen then rt_update_map_z(pz+1, false) end

	local x,z
	for z=pz-rt_sweepdist,pz+rt_sweepdist do
	if z >= 0 and z < zlen then
	for x=px-rt_sweepdist,px+rt_sweepdist do
	if x >= 0 and x < xlen then
		local pdata = common.img_pixel_get(rt_tex, x, z)
		local old_dist = math.floor(pdata / 0x01000000)
		if true or math.max(math.abs(x-px), math.abs(z-pz)) >= old_dist then
			pdata = pdata % 0x01000000
			common.img_pixel_set(rt_tex, x, z, pdata
				+ 0x01000000*rt_update_map_ring(x, z))
		end
	end
	end
	end
	end
end

do
	local va_map = common.va_make({
		{-1,-1},
		{ 1,-1},
		{-1, 1},
		{ 1, 1},
		{-1, 1},
		{ 1,-1},
	}, nil, "2v")
	local s_map_pillar_set = common.map_pillar_set
	function common.map_pillar_set(px, py, pl, ...)
		local ol = common.map_pillar_get(px, py)
		local ret = {s_map_pillar_set(px, py, pl, ...)}
		rt_update_map_check(px, py, ol, pl)
		return unpack(ret)
	end

	local s_map_render = client.map_render
	function client.map_render(map, px, py, pz, ...)
		local xlen, ylen, zlen = common.map_get_dims()
		shader_rt_map.set_uniform_i("tex0", 0)
		shader_rt_map.set_uniform_f("map_siz", xlen, zlen)
		shader_rt_map.set_uniform_f("tex0_siz", rt_xsi, rt_zsi)
		shader_rt_map.set_uniform_f("tex0_isiz", 1.0/rt_xsi, 1.0/rt_zsi)
		--shader_rt_map.set_uniform_f("light0_pos", -10.0, -math.max(xlen,zlen)/2, zlen/3+0.1)
		--shader_rt_map.set_uniform_f("light0_diff", 1.0)
		--shader_rt_map.set_uniform_f("light1_pos", xlen+10.0, -math.max(xlen,zlen)/2, zlen/4+0.1)
		--shader_rt_map.set_uniform_f("light1_diff", 1.0)

		local px, py, pz = client.camera_get_pos()
		local vx, vy, vz = client.camera_get_forward()
		local dist = trace_map_ray_dist(px, py, pz, vx, vy, vz, 50.0, false)
		dist = dist - 2.5
		shader_rt_map.set_uniform_f("light0_pos", px, py, pz)
		shader_rt_map.set_uniform_f("light0_diff", 0.5)
		--shader_rt_map.set_uniform_f("light0_diff", 1.0)
		shader_rt_map.set_uniform_f("light1_pos", px + dist*vx, py + dist*vy, pz + dist*vz)
		shader_rt_map.set_uniform_f("light1_diff", 1.1)

		-- TODO: track old FBOs
		client.gfx_depth_test(false);
		client.fbo_use(fbo_rt)
		client.gfx_viewport(0, 0, screen_width/rt_scale, screen_height/rt_scale)
		shader_rt_map.push()
		client.va_render_global(va_map, 0, 0, 0, 0, 0, 0, 1, {rt_tex})
		shader_rt_map.pop()

		client.fbo_use(nil)
		client.gfx_viewport(0, 0, screen_width, screen_height)
		shader_rt_img.set_uniform_i("tex0", 0)
		shader_rt_img.set_uniform_f("screen_siz", screen_width, screen_height)
		shader_rt_img.set_uniform_f("screen_isiz", 1.0/screen_width, 1.0/screen_height)
		shader_rt_img.set_uniform_f("tex0_scale", rt_scale)
		shader_rt_img.push()
		client.va_render_global(va_map, 0, 0, 0, 0, 0, 0, 1, {fbo_rt})
		shader_rt_img.pop()
		client.gfx_depth_test(true);

		--s_map_render(map, px, py, pz)--, ...)
	end
	rt_update_map_full()
end

fbo_world = nil

