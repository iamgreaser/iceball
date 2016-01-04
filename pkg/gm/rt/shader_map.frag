const int TRACE_MAX = 1000;
const float REFLECT_THRES = 0.1; //0.1; //0.02;
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

// Main runtime variables
vec3 wpos;
vec3 wdir;
vec3 cdir;
vec3 cell;
vec3 tcol = gl_Fog.color.rgb;
float tcol_remain = 1.0;
vec3 tnorm;
vec3 adir;
vec3 aidir;
vec3 aremsign;
vec3 last_agap;
vec2 lutc;
vec2 lutstep;
float lutc_gap;

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

vec2 lut_coord_xz(vec2 v)
{
	v = floor(v) + 0.2;
	vec4 c = floor(texture2D(tex0, v*tex0_isiz).bgra*255.0+0.2);
	//lutc_gap = floor(c.a/2.0);
	lutc_gap = c.a;
	return vec2(floor(c.y*256.0 + c.x + 0.2) + 0.2,
		floor(floor(v.y)*2.0 + c.z+0.2) + 0.2) * tex0_isiz;

}

float lut_skip(vec2 loc_lutc)
{
	vec4 v4 = floor(texture2D(tex0, loc_lutc)*255.0+0.2);
	vec2 v2 = vec2(
		aremsign.x >= 0.0 ? v4.g : v4.r,
		aremsign.z >= 0.0 ? v4.a : v4.b);
	
	//return 0.0;
	return dot(last_agap.xz, v2)*lutstep.x;
}

void do_reflect(vec3 ncol)
{
	//
	tcol = (1.0-tcol_remain)*tcol + (0.1)*tcol_remain*ncol;
	float diff0 = max(0.0, dot(-tnorm, normalize(wpos-light0_pos))) * light0_diff;
	float diff1 = max(0.0, dot(-tnorm, normalize(wpos-light1_pos))) * light1_diff;
	shadow_ncol0 = diff0*tcol_remain*ncol;
	shadow_ncol1 = diff1*tcol_remain*ncol;
	tcol_remain *= 0.2;

	if(last_agap.x != 0.0)
	{
		wdir.x *= -1.0;
		aremsign.x *= -1.0;
		cell.x += aremsign.x;
	} else if(last_agap.y != 0.0) {
		wdir.y *= -1.0;
		aremsign.y *= -1.0;
		cell.y += aremsign.y;
	} else {
		wdir.z *= -1.0;
		aremsign.z *= -1.0;
		cell.z += aremsign.z;
	}

	shadow_trace_next = true;
	shadow_sel = 0;
}

void main()
{
	vec3 wdir = normalize(wdir_in);
	/*vec3 fisheye = vec3(
		sin(dvec_in.x*3.141593*180.0/180.0/2.0),
		sin(dvec_in.y*3.141593*180.0/180.0/2.0),
		cos(dvec_in.x*3.141593*180.0/180.0/2.0)*
		cos(dvec_in.y*3.141593*180.0/180.0/2.0)
	);
	wdir = cdir_in*fisheye.z - camh_in*fisheye.x - camv_in*fisheye.y;
	*/
	wpos = wpos_in;
	cdir = cdir_in;

	cell = floor(wpos) + 0.2;
	cell.y = floor(cell.y);
	vec3 tsub = fract(wpos);
	//vec3 tcol = vec3(0.5, 0.0, 0.5);
	tnorm = -cdir;

	// Get abs stuff
	adir = abs(wdir);
	aidir = 1.0/max(vec3(0.00001),adir);
	aremsign = sign(wdir);

	vec3 arem;
	arem.x = aremsign.x >= 0.0 ? 1.0-tsub.x : tsub.x;
	arem.y = aremsign.y >= 0.0 ? 1.0-tsub.y : tsub.y;
	arem.z = aremsign.z >= 0.0 ? 1.0-tsub.z : tsub.z;

	lutc = lut_coord_xz(cell.xz);
	lutstep = vec2(tex0_isiz.x, 0.0);
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
				do_reflect(ncol);
				lutc = lut_coord_xz(cell.xz);

				continue;
			}

			// Advance
			lutc += lutstep*tgap.x;
			lutc_gap = 0.0;
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
				//vec3 ncol = texture2D(tex0, lutc + lutstep*(cell.y-tgap.w)).rgb;
				vec3 ncol = texture2D(tex0, lutc + lutstep*(cell.y-tgap.w-1.0)).rgb;
				do_reflect(ncol);
				lutc = lut_coord_xz(cell.xz);
				continue;
			}

			break;
		}

		//tcol = vec3(0.1, 1.0, 0.1);

		// Create space
		vec3 extgap = vec3(0.0, 0.0, 0.0);
		extgap.xz += lutc_gap;
		if(aremsign.y < 0.0)
		{
			extgap.y = cell.y-tgap.w;
		} else {
			extgap.y = (tgap.y-1.0)-cell.y;
		}
		arem += extgap;

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
		vec3 old_cell = cell;
		vec3 old_arem = arem;
		arem -= rtime*adir;
		wpos += rtime*wdir;
		cell += aremsign*agap;
		vec3 new_arem = arem;
		//arem *= 1.0-agap;
		//arem += agap;

		float ang = (rtime/50.0);
		float vs = sin(ang);
		float vc = cos(ang);

		// Set normal
		tnorm = -agap*aremsign;

		// Compensate for extgap
		// FIXME: This tends to break when you look down the corners of x=-z.
		arem = max(vec3(0.0), arem);

		// these are both as broken as each other
		//cell += aremsign*mix(ceil(old_arem) - ceil(max(vec3(0.0),arem)), extgap, agap);
		cell += aremsign*mix(floor(min(extgap, extgap+1.0-arem)), extgap, agap);

		cell = floor(cell+0.001);

		arem = mix(fract(max(vec3(0.0), arem)), vec3(1.0), agap);

		// Shift Y depending on result
		//if(agap.y == 0.0)
		//if(old_cell.x != cell.x || old_cell.z != cell.z)
		if(true)
		{
			/*
			if(new_arem.y < 0.0) new_arem.y = 0.0;
			cell.y += floor(floor(old_arem.y) - floor(new_arem.y) + 0.009)*aremsign.y;
			cell.y = floor(cell.y+0.1);
			arem.y = fract(arem.y);
			*/

			if(old_cell.x != cell.x || old_cell.z != cell.z)
			{
				float skip_val = lut_skip(lutc - lutstep);
				is_first_y = (skip_val == 0.0);
				lutc = lut_coord_xz(cell.xz) + vec2(skip_val, 0.0);
				if(!is_first_y) lutc_gap = 0.0;
			}
		} else {
			//cell.y += aremsign.y*(extgap.y-2.0);

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
				//ncol = texture2D(tex0, lutc - lutstep).rgb;
				ncol = texture2D(tex0, lutc - lutstep*2.0).rgb;
			else
				//tcol = gl_Fog.color.rgb;
				break;

			do_reflect(ncol);
			//lutc = lut_coord_xz(cell.xz);
		}
	}

	// Dither to improve quality
	// TODO: find an algo that isn't shit
	// (disabled for now, there's a chance this causes the banding that EVERYONE ELSE gets)
	//tcol += vec3(0.5/255.0)*sin(pow(dot(wdir_in,wdir_in.yzx)*1003.0, 3.0));

	gl_FragColor = vec4(tcol, 100.0/(100.0+atime));
}

