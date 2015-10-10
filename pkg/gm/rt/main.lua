local rt_scale = 4
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

]=], frag=[=[

const int TRACE_MAX = 1000;
const float REFLECT_THRES = 0.1; //0.02;
const int SHADOW_COUNT = 2;

uniform sampler2D tex0;
uniform vec2 map_siz;
uniform vec2 tex0_siz;
uniform vec2 tex0_isiz;

uniform vec3 light0_pos;
uniform vec3 light1_pos;
uniform float light0_diff;
uniform float light1_diff;

varying vec3 dvec_in;
varying vec3 camh_in;
varying vec3 camv_in;
varying vec3 wpos_in;
varying vec3 wdir_in;
varying vec3 cdir_in;

vec2 lut_coord_xz(vec2 v)
{
	v = floor(v) + 0.2;
	vec3 c = texture2D(tex0, v*tex0_isiz).bgr*255.0;
	return vec2(floor(c.y*256.0 + c.x + 0.2) + 0.2,
		floor(floor(v.y)*2.0 + c.z+0.2) + 0.2) * tex0_isiz;

}

void main()
{
	//vec3 wdir = (wdir_in / max(max(abs(wdir_in.x), abs(wdir_in.y)), abs(wdir_in.z)));
	vec3 wdir = normalize(wdir_in);
	/*vec3 fisheye = vec3(
		sin(dvec_in.x*3.141593*180.0/180.0/2.0),
		sin(dvec_in.y*3.141593*180.0/180.0/2.0),
		cos(dvec_in.x*3.141593*180.0/180.0/2.0)*
		cos(dvec_in.y*3.141593*180.0/180.0/2.0)
	);
	vec3 wdir = cdir_in*fisheye.z - camh_in*fisheye.x - camv_in*fisheye.y;
	*/
	vec3 wpos = wpos_in;
	vec3 cdir = cdir_in;

	//vec2 tpos = wpos.xz + wdir.xz/abs(wdir.y); // mode7 test
	vec3 cell = floor(wpos) + 0.2;
	cell.y = floor(cell.y);
	vec3 tsub = fract(wpos);
	//vec3 tcol = vec3(0.5, 0.0, 0.5);
	vec3 tcol = gl_Fog.color.rgb;
	float tcol_remain = 1.0;
	vec3 tnorm = -cdir;

	// Get abs stuff
	vec3 adir = abs(wdir);
	vec3 aidir = 1.0/max(vec3(0.00001),adir);
	vec3 aremsign = sign(wdir);
	vec3 last_agap = vec3(0.0, 0.0, 1.0);

	vec3 arem;
	arem.x = aremsign.x >= 0.0 ? 1.0-tsub.x : tsub.x;
	arem.y = aremsign.y >= 0.0 ? 1.0-tsub.y : tsub.y;
	arem.z = aremsign.z >= 0.0 ? 1.0-tsub.z : tsub.z;

	// Shadow info backup
	bool shadow_trace_next = false;
	int shadow_sel = 0;
	bool shadow_trace = false;
	bool shadow_is_skied = false;
	float shadow_atime = 0.0;
	vec3 shadow_ncol_light = vec3(0.0);
	vec3 shadow_light_pos = vec3(0.0);
	vec3 shadow_ncol0 = vec3(0.0);
	vec3 shadow_ncol1 = vec3(0.0);
	vec3 shadbak_wpos = vec3(0.0);
	vec3 shadbak_wdir = vec3(0.0);
	vec3 shadbak_cell = vec3(0.0);
	vec3 shadbak_adir = vec3(0.0);
	vec3 shadbak_aidir = vec3(0.0);
	vec3 shadbak_arem = vec3(0.0);
	vec3 shadbak_aremsign = vec3(0.0);
	vec3 shadbak_tnorm = vec3(0.0);
	float shadbak_atime = 0.0;

	vec2 lutc = lut_coord_xz(cell.xz);
	vec2 lutstep = vec2(tex0_isiz.x, 0.0);
	bool is_first_y = true;
	float atime = 0.0;

	for(int i = 0; i < TRACE_MAX; i++)
	{
		// Skip shadows if disabled
		if(shadow_trace_next && SHADOW_COUNT == 0)
		{
			shadow_trace_next = false;
			tcol += shadow_ncol0;
		}

		// Switch between main trace and shadow mode if necessary
		if(SHADOW_COUNT != 0 && shadow_trace)
		{
			//if(dot(wpos-shadow_light_pos, wdir) <= 0.0)
			if(atime >= shadow_atime)
			{
				shadow_trace_next = false;
			}
		}

		if(SHADOW_COUNT != 0 && shadow_trace && !shadow_trace_next)
		{
			// Determine if we hit the light first
			if(atime >= shadow_atime || (shadow_is_skied && cell.y <= 0.0))
			//if(dot(wpos-shadow_light_pos, wdir) <= 0.0 || (shadow_is_skied && cell.y <= 0.0))
			{
				tcol += shadow_ncol_light;
			}

			// Restore backup
			wpos = shadbak_wpos;
			wdir = shadbak_wdir;
			cell = shadbak_cell;
			adir = shadbak_adir;
			aidir = shadbak_aidir;
			arem = shadbak_arem;
			aremsign = shadbak_aremsign;
			tnorm = shadbak_tnorm;
			atime = shadbak_atime;

			lutc = lut_coord_xz(cell.xz);

			// Check if we need to move onto the next light
			shadow_sel += 1;
			if(shadow_sel < SHADOW_COUNT)
			{
				shadow_trace_next = true;
				shadow_trace = false;
			}
		}

		if(SHADOW_COUNT != 0 && shadow_trace_next && !shadow_trace)
		{
			// Back everything up
			shadbak_wpos = wpos;
			shadbak_wdir = wdir;
			shadbak_cell = cell;
			shadbak_adir = adir;
			shadbak_aidir = aidir;
			shadbak_arem = arem;
			shadbak_aremsign = aremsign;
			shadbak_tnorm = tnorm;
			shadbak_atime = atime;

			// Pick new casting direction

			if(shadow_sel == 0)
			{
				shadow_light_pos = light0_pos;
				shadow_ncol_light = shadow_ncol0;
			} else {
				shadow_light_pos = light1_pos;
				shadow_ncol_light = shadow_ncol1;
			}

			shadow_is_skied = (shadow_light_pos.y < 1.0);

			//wpos = cell+arem*-aremsign+(aremsign+1.0)/2.0;
			shadow_atime = length(shadow_light_pos - wpos) + atime;
			wdir = normalize(shadow_light_pos - wpos);
			adir = abs(wdir);
			aidir = 1.0/max(vec3(0.00001),adir);
			aremsign = sign(wdir);
			arem.x = aremsign.x*shadbak_aremsign.x < 0.0 ? 1.0-arem.x : arem.x;
			arem.y = aremsign.y*shadbak_aremsign.y < 0.0 ? 1.0-arem.y : arem.y;
			arem.z = aremsign.z*shadbak_aremsign.z < 0.0 ? 1.0-arem.z : arem.z;

		}

		shadow_trace = shadow_trace_next;

		if(shadow_trace)
		{
			// Termination condition

		} else if(tcol_remain < REFLECT_THRES) {
			break;
		}

		// Check if in bounds
		/*
		if(cell.y < 0.0)
		{
			tcol = gl_Fog.color.rgb;
			tnorm = vec3(0.0, 1.0, 0.0)*(cell.y < 0.0 ? 1.0 : -1.0);
			break;
		}
		*/

		/*
		if(cell.x < 0.0 || cell.x >= map_siz.x)
		{
			tcol = gl_Fog.color.rgb;
			tnorm = vec3(1.0, 0.0, 0.0)*(cell.x < 0.0 ? 1.0 : -1.0);
			break;
		}

		if(cell.z < 0.0 || cell.z >= map_siz.y)
		{
			tcol = gl_Fog.color.rgb;
			tnorm = vec3(0.0, 0.0, 1.0)*(cell.z < 0.0 ? 1.0 : -1.0);
			break;
		}
		*/
		if(cell.x < 0.0 || cell.x >= map_siz.x || cell.z < 0.0 || cell.z >= map_siz.y)
		{
			break;
		}

		// Get trace gap
		vec4 tgap = floor(texture2D(tex0, lutc)*255.0+0.4).bgra;

		//if(cell.y >= 256.0) { tcol = vec3(1.0, 0.0, 0.0); break; }

		// Check if greater than end
		if(cell.y >= tgap.y)
		{
			// Check if in top
			if(cell.y <= tgap.z || tgap.x == 0.0)
			{
				if(shadow_trace)
				{
					shadow_trace_next = false;
					continue;
				}

				// We've hit the floor, set that colour
				vec3 ncol = texture2D(tex0, lutc + lutstep*(cell.y-tgap.y+1.0)).rgb;
				tcol = (1.0-tcol_remain)*tcol + (0.1)*tcol_remain*ncol;
				float diff0 = max(0.0, dot(-tnorm, normalize(wpos-light0_pos))) * light0_diff;
				float diff1 = max(0.0, dot(-tnorm, normalize(wpos-light1_pos))) * light1_diff;
				shadow_ncol0 = diff0*tcol_remain*ncol;
				shadow_ncol1 = diff1*tcol_remain*ncol;
				tcol_remain *= 0.2;
				//break;

				// Reflect
				if(last_agap.x != 0.0)
				{
					wdir.x *= -1.0;
					aremsign.x *= -1.0;
					cell.x += aremsign.x;
				} else {
					wdir.z *= -1.0;
					aremsign.z *= -1.0;
					cell.z += aremsign.z;
				}

				lutc = lut_coord_xz(cell.xz);
				shadow_trace_next = true;
				shadow_sel = 0;

				continue;
			}

			// Advance
			lutc += lutstep*tgap.x;
			is_first_y = false;
			continue;
		}

		// Check if less than air
		// FIXME: make this behave when above the skyline
		if(cell.y < tgap.w)
		{
			if(shadow_trace)
			{
				shadow_trace_next = false;
				continue;
			}

			// We've hit the ceiling, set that colour if not sky
			if(!is_first_y)
			{
				vec3 ncol = texture2D(tex0, lutc + lutstep*(cell.y-tgap.w)).rgb;
				tcol = (1.0-tcol_remain)*tcol + (0.1)*tcol_remain*ncol;
				float diff0 = max(0.0, dot(-tnorm, normalize(wpos-light0_pos))) * light0_diff;
				float diff1 = max(0.0, dot(-tnorm, normalize(wpos-light1_pos))) * light1_diff;
				shadow_ncol0 = diff0*tcol_remain*ncol;
				shadow_ncol1 = diff1*tcol_remain*ncol;
				tcol_remain *= 0.2;

				// Reflect
				if(last_agap.x != 0.0)
				{
					wdir.x *= -1.0;
					aremsign.x *= -1.0;
					cell.x += aremsign.x;
				} else {
					wdir.z *= -1.0;
					aremsign.z *= -1.0;
					cell.z += aremsign.z;
				}

				lutc = lut_coord_xz(cell.xz);
				shadow_trace_next = true;
				shadow_sel = 0;
				continue;
			}

			break;
		}

		//tcol = vec3(0.1, 1.0, 0.1);

		// Create space
		float extgap_y = 0.0;
		if(aremsign.y < 0.0)
		{
			extgap_y = cell.y-tgap.w;
		} else {
			extgap_y = (tgap.y-1.0)-cell.y;
		}
		arem.y += extgap_y;

		// Get time
		vec3 ttime = max(vec3(0.0), arem*aidir);

		// Find smallest time & side
		vec3 agap;
		if(ttime.x <= ttime.y && ttime.x <= ttime.z)
			agap = vec3(1.0, 0.0, 0.0);
		else if(ttime.y <= ttime.z)
			agap = vec3(0.0, 1.0, 0.0);
		else
			agap = vec3(0.0, 0.0, 1.0);

		last_agap = agap;
		//tcol = agap*0.05;

		// Add remainder
		float rtime = dot(ttime, agap);
		atime += rtime;
		float old_arem_y = arem.y;
		arem -= rtime*adir;
		wpos += rtime*wdir;
		cell += aremsign*agap;
		arem *= 1.0-agap;
		arem += agap;

		float ang = (rtime/50.0);
		float vs = sin(ang);
		float vc = cos(ang);

		// Set normal
		tnorm = -agap*aremsign;

		// Shift Y depending on result
		if(agap.y == 0.0)
		{
			if(arem.y < 0.0) arem.y = 0.0;
			cell.y += floor(floor(old_arem_y) - floor(arem.y) + 0.009)*aremsign.y;
			cell.y = floor(cell.y);
			arem.y = fract(arem.y);
			is_first_y = true;
			lutc = lut_coord_xz(cell.xz);
		} else {
			cell.y += aremsign.y*(extgap_y-1.0);

			if(shadow_trace)
			{
				shadow_trace_next = false;
				continue;
			}

			// Set to either floor or ceiling
			vec3 ncol;
			if(wdir.y > 0.0)
				ncol = texture2D(tex0, lutc + lutstep).rgb;
			else if(!is_first_y)
				ncol = texture2D(tex0, lutc - lutstep).rgb;
			else
				//tcol = gl_Fog.color.rgb;
				break;

			tcol = (1.0-tcol_remain)*tcol + (0.1)*tcol_remain*ncol;
			float diff0 = max(0.0, dot(-tnorm, normalize(wpos-light0_pos))) * light0_diff;
			float diff1 = max(0.0, dot(-tnorm, normalize(wpos-light1_pos))) * light1_diff;
			shadow_ncol0 = diff0*tcol_remain*ncol;
			shadow_ncol1 = diff1*tcol_remain*ncol;
			tcol_remain *= 0.2;
			//break;

			// Try for a reflection!
			wdir.y *= -1.0;
			aremsign.y *= -1.0;
			shadow_trace_next = true;
			shadow_sel = 0;
			//lutc = lut_coord_xz(cell.xz);
		}
	}

	//vec3 tcol = texture2D(tex0, lutc + lutstep*1.0).rgb;
	//vec3 tcol = vec3(lutc, 0.0);
	//vec3 tcol = vec3(cell/512.0, 0.0);

	//const float AMBIENT = 0.2;
	//float diffamb = AMBIENT + (1.0-AMBIENT) * dot(wdir, -tnorm);

	//gl_FragColor = vec4(tcol * diffamb, 1.0);

	// Dither to improve quality
	// TODO: find an algo that isn't shit
	tcol += vec3(0.5/255.0)*sin(pow(dot(wdir_in,wdir_in.yzx)*1003.0, 3.0));

	gl_FragColor = vec4(tcol, 100.0/(100.0+atime));
}

]=]}

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

local function rt_update_map_z(pz)
	local xlen, ylen, zlen = common.map_get_dims()
	local xoffs0 = xlen
	local xoffs1 = xlen
	local x, y, z
	z = pz

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

		common.img_pixel_set(rt_tex, x, z, xoffs + (zoffs*0x010000) + 0xFF000000)

		for y=0,#l-1,4 do
			assert(xoffs < rt_xsi)
			common.img_pixel_set(rt_tex, xoffs, z*2 + zoffs,
				0
				+ (l[y+1])
				+ (l[y+2])*(256)
				+ (l[y+3])*(65536)
				+ (l[y+4])*(65536*256)
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
				xsum0 = xsum0 + #(common.map_pillar_get(x, z))
			else
				xsum1 = xsum1 + #(common.map_pillar_get(x, z))
			end
		end

		local xsum = math.max(xsum0, xsum1)

		xmax = math.max(xmax, xsum/4)
	end

	while rt_xsi < xmax+xlen+256 do -- allow extra space
		rt_xsi = rt_xsi * 2
	end
	print("xmax:", xmax, xmax+xlen, rt_xsi)

	-- Create texture
	rt_tex = common.img_new(rt_xsi, rt_zsi)

	-- Copy data to GPU
	for z=0,zlen-1 do
		rt_update_map_z(z)
		print((z+1)*100/zlen)
	end

	-- Force image commit
	--client.img_blit(rt_tex, 0, 0)

	-- TODO: make this work
	rt_force_update_full = false
end

local function rt_update_map_check(px, pz, nl)
	if rt_force_update_full then
		return rt_update_map_full()
	end

	local i
	local ol = common.map_pillar_get(px, pz)
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

	rt_update_map_z(pz)
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
		rt_update_map_check(px, py, pl)
		return s_map_pillar_set(px, py, pl, ...)
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
		shader_rt_map.set_uniform_f("light1_pos", px + dist*vx, py + dist*vy, pz + dist*vz)
		shader_rt_map.set_uniform_f("light1_diff", 2.0)

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

