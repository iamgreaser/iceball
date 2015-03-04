return shader_new{name="post_stereo", vert=[=[
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

	return depth_B/(buf-depth_A);
	// get 1/z
	//return (buf-depth_A)/depth_B;
}

void main()
{
	vec2 tc = gl_TexCoord[0].st;
	float dbval = texture2D(tex1, tc).x;
	float db = getdepth(dbval);
	vec2 tc0 = tc;
	vec2 tc1 = tc;
	float sep = min(0.1,0.1/db);
	tc0.x -= sep;
	tc1.x += sep;
	vec4 color0 = texture2D(tex0, tc0);
	vec4 color1 = texture2D(tex0, tc1);

	// mild desaturation
	float lum0 = dot(color0.rgb, vec3(0.3,0.5,0.2));
	float lum1 = dot(color1.rgb, vec3(0.3,0.5,0.2));
	color0 -= lum0;
	color1 -= lum1;
	color0 *= 0.5;
	color1 *= 0.5;
	color0 += lum0;
	color1 += lum1;

	vec4 color = vec4(
		color0.r,
		color1.g,
		color1.b,
		1.0);

	float distamp = length((tc*2.0-1.0)*(soffs.x/soffs)); // TODO: get correct FOV
	float realdist = (1.0/db)*length(vec2(1.0, distamp));
	float fog_strength = min(1.0, realdist/fog);
	fog_strength *= fog_strength;
	gl_FragColor = color * (1.0 - fog_strength)
		+ gl_Fog.color * fog_strength;
}

]=]}

