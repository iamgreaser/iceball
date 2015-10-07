--[[
DCT + IDCT mod for Iceball

WARNING: This mod is covered by software patents.

Not that I actually know which ones, but due to the nature of this being
useful for any possible video application whatsoever, it's guaranteed to be covered
by some stupid bullshit patent that doesn't have any right to exist,
but exists anyway because the US govt are a bunch of fucking morons.

After all, it's a GPU implementation of a DCT in GLSL,
which is really fucking useful for video,
and oddly enough is what I intend to use it for eventually.

This means that it's probably covered by these hypothetical patents:

* Method for calculating a DCT on a GPU
* Method for calculating a DCT using GLSL
* Method for calculating a fast DCT
* Method for calculating a fast DCT on a GPU
* Method for calculating anything related to fourier transforms on a GPU
* Method for storing signed colour data in an 8bpc space
* Method for compressing (in the audio sense, not in the data sense) values into an 8bpc space 
* Method for compressing values into an 8bpc space, number two
* Method for compressing values into an 8bpc space, number three
* Method for converting between colourspaces on a GPU
* Method for running programs on a GPU, filed because the clerk at the patent office wasn't looking
* Method for calculating a DCT in a video game, on a GPU
* Method for calculating a DCT in a networked video game, on a GPU
* Method for sending a DCT algorithm over a network
* Method for sending a GLSL shader over a network
* And any apparatus for applying any of those methods.

So please, if you use this software, either:

* Ensure that you are in a country that doesn't give software patents any more respect than they deserve (read: none),

or:

* Don't tell IBM.

Thank you.

P.S. If you own any patents that covers this piece of software,
please let me know so I can work out how to make a modified version
that doesn't violate any of your patents.

P.P.S. No, I am not going to settle for a patent licensing deal.

]]

if not (USE_FBO and USE_GLSL_21) then return end

fbo_dct_apply1 = client.fbo_create(screen_width, screen_height, true)
fbo_dct_apply2 = client.fbo_create(screen_width, screen_height, false)
fbo_dct_unapply1 = client.fbo_create(screen_width, screen_height, false)
fbo_dct_unapply2 = client.fbo_create(screen_width, screen_height, false)

shader_dct_apply, result = shader_new{name="dct_apply", 
vert=[=[
#version 120
// Vertex shader

void main()
{
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_TexCoord[0] = gl_MultiTexCoord0;
}

]=], frag=[=[
#version 120
// Fragment shader

uniform sampler2D tex0;
uniform vec2 smul;
uniform vec2 smul_inv;
uniform float is_init;
uniform float is_fini;
uniform float is_inverse;

const float[] sfac = float[]( 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0 );

// TODO: replace this with a proper floating-point version
// rather than a fixed point integer version divided by its 1.0 representation
/*
const float[] cosinetab = float[](
	0.3515625,  0.3515625,  0.3515625,  0.3515625,  0.3515625,  0.3515625,  0.3515625,  0.3515625,
	0.48828125, 0.4140625,  0.27734375, 0.09375,   -0.09375,   -0.27734375,-0.4140625, -0.48828125,
	0.4609375,  0.1875,    -0.1875,    -0.4609375, -0.4609375, -0.1875,     0.1875,     0.4609375,
	0.4140625, -0.09375,   -0.48828125,-0.27734375, 0.27734375, 0.48828125, 0.09375,   -0.4140625,
	0.3515625, -0.3515625, -0.3515625,  0.3515625,  0.3515625, -0.3515625, -0.3515625,  0.3515625,
	0.27734375,-0.48828125, 0.09375,    0.4140625, -0.4140625, -0.09375,    0.48828125,-0.27734375,
	0.1875,    -0.4609375,  0.4609375, -0.1875,    -0.1875,     0.4609375, -0.4609375,  0.1875,
	0.09375,   -0.27734375, 0.4140625, -0.48828125, 0.48828125,-0.4140625,  0.27734375,-0.09375
);
*/

//const int[] deint_tab_y = int[](0,4,2,6,1,3,5,7);
const int[] deint_tab_y = int[](0,4,2,5,1,6,3,7);

const float recode_thres = 0.1;
const float recode_div = 40.0;
vec3 color_recode(vec3 c)
{
	vec3 s = sign(c);
	c = abs(c);

	if(c.r > recode_thres) c.r = (c.r-recode_thres)/recode_div + recode_thres;
	if(c.g > recode_thres) c.g = (c.g-recode_thres)/recode_div + recode_thres;
	if(c.b > recode_thres) c.b = (c.b-recode_thres)/recode_div + recode_thres;

	c *= s;
	c += 0.5;
	return c;
}

vec3 color_decode(vec3 c)
{
	c -= 0.5;

	vec3 s = sign(c);
	c = abs(c);

	if(c.r > recode_thres) c.r = (c.r-recode_thres)*recode_div + recode_thres;
	if(c.g > recode_thres) c.g = (c.g-recode_thres)*recode_div + recode_thres;
	if(c.b > recode_thres) c.b = (c.b-recode_thres)*recode_div + recode_thres;

	c *= s;
	return c;
}

vec3 space_recode(vec3 c)
{
	float l = (c.r+c.g*2.0+c.b)/4.0;
	float cr = c.r-l;
	float cb = c.b-l;
	return vec3(l, cr, cb);
}

vec3 space_decode(vec3 c)
{
	float l = c.r;
	float cr = c.g;
	float cb = c.b;

	float r = cr+l;
	float b = cb+l;
	float g = (l*4.0-r-b)/2.0;
	return vec3(r, g, b);
}

void main()
{
	// Get texcoord in pixels
	vec2 tc = gl_TexCoord[0].st * smul;

	// useful for debugging: skip pass
	if(false)
	{
		vec4 color = texture2D(tex0, tc * smul_inv);
		color.a = 1.0;
		gl_FragColor = color;
		return;
	}

	// Get sub texcoords
	tc += 0.02;
	vec2 tcq = floor(tc / 8.0)*8.0;
	vec2 tcr = floor(tc - tcq + 0.02);
	tcq += 0.4;

	vec2 offs_x = vec2(0.0, 1.0);
	vec2 tcf = vec2(tcr.y, 0.0);
	int iquant = int(tcr.x+0.1);

	// Fetch pixels
	vec3 color0 = texture2D(tex0, (tcq + tcf + 0.0*offs_x) * smul_inv).rgb;
	vec3 color1 = texture2D(tex0, (tcq + tcf + 1.0*offs_x) * smul_inv).rgb;
	vec3 color2 = texture2D(tex0, (tcq + tcf + 2.0*offs_x) * smul_inv).rgb;
	vec3 color3 = texture2D(tex0, (tcq + tcf + 3.0*offs_x) * smul_inv).rgb;
	vec3 color4 = texture2D(tex0, (tcq + tcf + 4.0*offs_x) * smul_inv).rgb;
	vec3 color5 = texture2D(tex0, (tcq + tcf + 5.0*offs_x) * smul_inv).rgb;
	vec3 color6 = texture2D(tex0, (tcq + tcf + 6.0*offs_x) * smul_inv).rgb;
	vec3 color7 = texture2D(tex0, (tcq + tcf + 7.0*offs_x) * smul_inv).rgb;

	// Work out matrix to apply
	bool do_transp = !(is_inverse != 0.0);
	int quantmul = (do_transp ? 8 : 1);
	int stepmul  = (do_transp ? 1 : 8);

	// Decode interim DCT values
	if(is_init == 0.0)
	{
		color0 = color_decode(color0);
		color1 = color_decode(color1);
		color2 = color_decode(color2);
		color3 = color_decode(color3);
		color4 = color_decode(color4);
		color5 = color_decode(color5);
		color6 = color_decode(color6);
		color7 = color_decode(color7);
	} else {
		color0 = space_decode(color0);
		color1 = space_decode(color1);
		color2 = space_decode(color2);
		color3 = space_decode(color3);
		color4 = space_decode(color4);
		color5 = space_decode(color5);
		color6 = space_decode(color6);
		color7 = space_decode(color7);
	}

	// Apply DCT/IDCT
	vec3 color;

	if(do_transp)
	{
		int iqint = deint_tab_y[iquant];

		if(iqint >= 4)
		{
			vec3 g0 = (color0-color7);
			vec3 g1 = (color1-color6);
			vec3 g2 = (color2-color5);
			vec3 g3 = (color3-color4);
			const float t0 = 0.48828125;
			const float t1 = 0.4140625;
			const float t2 = 0.27734375;
			const float t3 = 0.09375;

			if(iqint == 4)
			{
				color = t0*g0 + t1*g1 + t2*g2 + t3*g3;
			} else if(iqint == 5) {
				color = t1*g0 - t3*g1 - t0*g2 - t2*g3;
			} else if(iqint == 6) {
				color = t2*g0 - t0*g1 + t3*g2 + t1*g3;
			} else if(iqint == 7) {
				color = t3*g0 - t2*g1 + t1*g2 - t0*g3;
			}

		} else if(iqint >= 2) {
			vec3 g0 = (color0-color3-color4+color7);
			vec3 g1 = (color1-color2-color5+color6);
			color = (iqint == 2
				? 0.1875*g1 + 0.4609375*g0
				: 0.1875*g0 - 0.4609375*g1
			);

		} else {
			vec3 g0 = (color0+color3+color4+color7);
			vec3 g1 = (color1+color2+color5+color6);
			color = 0.3515625*(iqint == 0 ? g0+g1 : g0-g1);
		}

		/*
		color0 = color0*cosinetab[8*iquant+0];
		color1 = color1*cosinetab[8*iquant+1];
		color2 = color2*cosinetab[8*iquant+2];
		color3 = color3*cosinetab[8*iquant+3];
		color4 = color4*cosinetab[8*iquant+4];
		color5 = color5*cosinetab[8*iquant+5];
		color6 = color6*cosinetab[8*iquant+6];
		color7 = color7*cosinetab[8*iquant+7];
		color = (color0 + color1 + color2 + color3 + color4 + color5 + color6 + color7);
		*/
	} else {
		const float t0 = 0.48828125;
		const float t1 = 0.4140625;
		const float t2 = 0.27734375;
		const float t3 = 0.09375;

		bool mflip1 = (iquant >= 4);
		int msel1 = (mflip1 ? 7-iquant : iquant);
		bool msel2 = (msel1 >= 2);
		bool msel0 = (msel1 == 0 || msel1 == 3);

		vec3 m0 = 0.3515625*(msel0
			? color0 + color4
			: color0 - color4);

		vec3 m2 = (msel0
			? 0.4609375*color2 +   0.18750*color6
			:   0.18750*color2 - 0.4609375*color6);
		m2 = (msel2 ? -m2 : m2);

		vec3 m1;
		if(msel1 == 0)
		{
			m1 = t0*color1+t1*color3+t2*color5+t3*color7;
		} else if(msel1 == 1) {
			m1 = t1*color1-t3*color3-t0*color5-t2*color7;
		} else if(msel1 == 2) {
			m1 = t2*color1-t0*color3+t3*color5+t1*color7;
		} else {
			m1 = t3*color1-t2*color3+t1*color5-t0*color7;
		}
		m1 = (mflip1 ? -m1 : m1);
		color = m0+m1+m2;

		/*
		color0 = color0*cosinetab[iquant+8*0];
		color1 = color1*cosinetab[iquant+8*1];
		color2 = color2*cosinetab[iquant+8*2];
		color3 = color3*cosinetab[iquant+8*3];
		color4 = color4*cosinetab[iquant+8*4];
		color5 = color5*cosinetab[iquant+8*5];
		color6 = color6*cosinetab[iquant+8*6];
		color7 = color7*cosinetab[iquant+8*7];
		color = (color0 + color1 + color2 + color3 + color4 + color5 + color6 + color7);
		*/
	}


	// Encode interim DCT value
	if(is_fini == 0.0)
		color = color_recode(color);
	else
		color = space_recode(color);

	gl_FragColor = vec4(color, 1.0);
}

]=]}

assert(shader_dct_apply, result)

function dct_apply_scene()
	if fbo_dct_apply1 then
		shader_dct_apply.set_uniform_i("tex0", 0)
		shader_dct_apply.set_uniform_f("smul", screen_width, screen_height)
		shader_dct_apply.set_uniform_f("smul_inv", 1.0/screen_width, 1.0/screen_height)

		client.fbo_use(fbo_dct_apply2)
		shader_dct_apply.set_uniform_f("is_init", 1.0)
		shader_dct_apply.set_uniform_f("is_fini", 0.0)
		shader_dct_apply.set_uniform_f("is_inverse", 0.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_apply1, 0, 0)
		shader_dct_apply.pop()

		client.fbo_use(fbo_dct_unapply1)
		shader_dct_apply.set_uniform_f("is_init", 0.0)
		shader_dct_apply.set_uniform_f("is_fini", 0.0)
		shader_dct_apply.set_uniform_f("is_inverse", 0.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_apply2, 0, 0)
		shader_dct_apply.pop()

		client.fbo_use(fbo_dct_unapply2)
		shader_dct_apply.set_uniform_f("is_init", 0.0)
		shader_dct_apply.set_uniform_f("is_fini", 0.0)
		shader_dct_apply.set_uniform_f("is_inverse", 1.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_unapply1, 0, 0)
		shader_dct_apply.pop()

		client.fbo_use(nil)
		shader_dct_apply.set_uniform_f("is_init", 0.0)
		shader_dct_apply.set_uniform_f("is_fini", 1.0)
		shader_dct_apply.set_uniform_f("is_inverse", 1.0)
		shader_dct_apply.push()
		client.img_blit(fbo_dct_unapply2, 0, 0)
		shader_dct_apply.pop()

	end
end

do
	local s_hook_render = client.hook_render
	function client.hook_render(...)
		local s_fbo_use = client.fbo_use
		local is_using_nil = true
		local s_img_dump = client.img_dump
		function client.fbo_use(fbo, ...)
			if fbo == nil then
				is_using_nil = true
				return s_fbo_use(fbo_dct_apply1, ...)
			else
				is_using_nil = false
				return s_fbo_use(fbo, ...)
			end
		end

		function client.img_dump(...)
			if is_using_nil then s_fbo_use(nil) end
			local ret = {s_img_dump(...)}
			if is_using_nil then s_fbo_use(fbo_dct_apply1) end
			return unpack(ret)
		end

		s_fbo_use(fbo_dct_apply1)

		s_hook_render()

		client.fbo_use = s_fbo_use
		client.img_dump = s_img_dump

		dct_apply_scene()
		s_fbo_use(fbo_dct_apply1)
	end
end
