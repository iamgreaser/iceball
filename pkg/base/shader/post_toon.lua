return shader_new{name="post_toon", vert=[=[
// Vertex shader

void main()
{
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_TexCoord[0] = gl_MultiTexCoord0;
}

]=], frag=[=[
// Fragment shader

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform vec2 soffs;
uniform float time;
uniform float fog;
uniform float depth_A;
uniform float depth_B;

float getdepth(float buf)
{
	/*
	const float f = 127.5;
	const float n = 0.05;
	// TODO: fetch correct fog and zoom

	// d = (Az+B)/(Cz+D)
	// d(Cz+D) = (Az+B)
	// Czd+Dd = Az+B
	// Czd-Az = B-Dd
	// z(Cd-A) = B-Dd
	// z = (B-Dd)/(Cd-A)

	// Note, commented code is correct
	//const float A = (f+n)/(f-n);
	//const float B = -(2.0*f*n)/(f-n);
	//const float C = 1.0;
	//return B/(C*buf-A);
	//return (B/C)/(buf-(A/C)); // saves a calculation step

	const float A = (f+n)/(f-n);
	const float B = -(2.0*f*n)/(f-n);
	return B/(buf-A);
	*/

	// Hypothetically faster when f,n not precalced
	/*
	const float A = (f+n);
	const float B = -(2.0*f*n);
	return B/((f-n)*buf-A);
	*/

	//return depth_B/(buf-depth_A);
	// get 1/z
	return (buf-depth_A)/depth_B;
}

void main()
{
	vec2 tc = gl_TexCoord[0].st;
	float dbval = texture2D(tex1, tc).x;
	vec4 color = texture2D(tex0, tc);
	/*
	if(dbval > 0.9999)
	{
		vec3 c = abs(tcolor.rgb - gl_Fog.color.rgb);
		if(max(max(c.r,c.g),c.b) < 0.01)
			discard;
	}
	*/

	float db = getdepth(dbval);
	/*
	float doffs = (1.0/db < (1.0/soffs.y)/40.0
		? 2.0
		: 1.0);
	*/
	float doffs = 1.0;
	float dxn1 = getdepth(texture2D(tex1, tc + soffs*doffs*vec2(-1.0, 0.0)).x);
	float dxp1 = getdepth(texture2D(tex1, tc + soffs*doffs*vec2( 1.0, 0.0)).x);
	float dyn1 = getdepth(texture2D(tex1, tc + soffs*doffs*vec2( 0.0,-1.0)).x);
	float dyp1 = getdepth(texture2D(tex1, tc + soffs*doffs*vec2( 0.0, 1.0)).x);
	float dxn2 = db - dxn1;
	float dxp2 = dxp1 - db;
	float dyn2 = db - dyn1;
	float dyp2 = dyp1 - db;
	const float dpurethres_min = 0.0006;
	const float dpurethres_max = 0.0020;
	const float dpurethres_delta = dpurethres_max-dpurethres_min;
	float dpuregapx = abs(dxn2 - dxp2);
	float dpuregapy = abs(dyn2 - dyp2);
	float dpuregap = max(dpuregapx, dpuregapy)/db;
	float distamp = length((tc*2.0-1.0)*(soffs.x/soffs)); // TODO: get correct FOV
	float realdist = (1.0/db)*length(vec2(1.0, distamp));
	float fog_strength = min(1.0, realdist/fog);
	fog_strength *= fog_strength;
	if(dpuregap > dpurethres_min)
	{
		color *= max(0.0, 1.0-(dpuregap-dpurethres_min)/dpurethres_delta);
		/*
		float color_acc = 1.0;
		float fxaa_color_acc = 0.0;
		vec4 fxaa_color = vec4(0.0);

		if(dpuregapx > dpurethres_min)
		{
			color_acc *= 0.5;
			fxaa_color_acc += 2.0;
			fxaa_color += texture2D(tex0, tc + soffs*vec2(-1.0, 0.0));
			fxaa_color += texture2D(tex0, tc + soffs*vec2( 1.0, 0.0));
		}

		if(dpuregapy > dpurethres_min)
		{
			color_acc *= 0.5;
			fxaa_color_acc += 2.0;
			fxaa_color += texture2D(tex0, tc + soffs*vec2( 0.0,-1.0));
			fxaa_color += texture2D(tex0, tc + soffs*vec2( 0.0, 1.0));
		}

		if(fxaa_color_acc >= 1.0)
			color = color_acc*color + (1.0-color_acc)*(fxaa_color/fxaa_color_acc);
		*/
	}
	color.a = 1.0;
	gl_FragColor = color * (1.0 - fog_strength)
		+ gl_Fog.color * fog_strength;
}

]=]}

