return shader_new{name="world_diff", vert=[=[
// Vertex shader

varying vec4 cpos;
varying vec4 wpos;
varying vec4 wnorm;
varying float fogmul;
uniform float time;

void main()
{
	wpos = gl_Vertex;
	cpos = (gl_ModelViewMatrixInverse * vec4(0.0, 0.0, 0.0, 1.0));
	wnorm = vec4(normalize(gl_Normal), 0.0);
	fogmul = 1.0 / (length(gl_ModelViewMatrixInverse * vec4(0.0, 0.0, -1.0, 0.0)) * gl_Fog.end);

	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * wpos;
	gl_FrontColor = gl_Color;
	//gl_TexCoord[0] = (gl_MultiTexCoord0 * 64.0 + vec4(64.0*4.0, 64.0*4.0, 0.0, 0.0))/512.0;
	gl_TexCoord[0] = vec4(
		dot(wpos.xyz, gl_Normal.yzx)/16.0,
		dot(wpos.xyz, gl_Normal.zxy)/16.0,
		0.0, 0.0);
	gl_TexCoord[0] -= vec4(ivec4(gl_TexCoord[0]));
}

]=], frag=[=[
// Fragment shader

varying vec4 cpos;
varying vec4 wpos;
varying vec4 wnorm;
varying float fogmul;

uniform vec4 sun;
uniform sampler2D tex0;
uniform vec2 map_idims;

void main()
{
	float fog_strength = min(1.0, length((wpos - cpos).xyz) * fogmul);
	fog_strength *= fog_strength;

	vec4 color = gl_Color;
	vec4 camto = vec4(normalize((wpos - cpos).xyz), 0.0);

	// Diffuse
	float diff = max(0.0, dot(-camto, wnorm));
	diff = 0.2 + 0.5*diff;

	// Sky shadow
	vec4 owpos = wpos + wnorm*0.001;
	owpos.x -= 0.5;
	owpos.z -= 0.5;
	vec2 subpos1 = sin((fract(owpos.xz)*2.0-1.0)*3.141593/2.0)*0.5+0.5;
	vec2 subpos0 = 1.0 - subpos1;
	float t00 = texture2D(tex0, (owpos.xz + vec2(0.01,  0.01)) * map_idims).b * 255.0;
	float t01 = texture2D(tex0, (owpos.xz + vec2(0.01,  0.99)) * map_idims).b * 255.0;
	float t10 = texture2D(tex0, (owpos.xz + vec2(0.99,  0.01)) * map_idims).b * 255.0;
	float t11 = texture2D(tex0, (owpos.xz + vec2(0.99,  0.99)) * map_idims).b * 255.0;
	t00 = (owpos.y < t00 ? 1.0 : 0.0)*subpos0.x*subpos0.y;
	t01 = (owpos.y < t01 ? 1.0 : 0.0)*subpos0.x*subpos1.y;
	t10 = (owpos.y < t10 ? 1.0 : 0.0)*subpos1.x*subpos0.y;
	t11 = (owpos.y < t11 ? 1.0 : 0.0)*subpos1.x*subpos1.y;
	diff += 0.8*(t00+t01+t10+t11);

	// Specular
	// disabling until it makes sense
	/*
	vec4 specdir = normalize(2.0*dot(wnorm, -sun)*wnorm - -sun);
	float spec = max(0.0, dot(-camto, specdir));
	spec = pow(spec, 32.0)*0.6;
	*/

	diff = diff * (1.0 - fog_strength);
	diff = min(1.5, diff);
	color = vec4(color.rgb * diff, color.a);
	color = max(vec4(0.0), min(vec4(1.0), color));
	//color = vec4(0.5+0.5*sin(3.141593*(color.rgb-0.5)), color.a);

	gl_FragColor = color * (1.0 - fog_strength)
		+ gl_Fog.color * fog_strength;
}
]=]}

