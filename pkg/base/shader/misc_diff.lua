return shader_new{name="misc_diff",
vert=[=[
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
	gl_TexCoord[0] = gl_MultiTexCoord0;
}

]=], frag=[=[
// Fragment shader

varying vec4 cpos;
varying vec4 wpos;
varying vec4 wnorm;
varying float fogmul;

uniform vec4 sun;

uniform sampler2D tex0;

void main()
{
	float fog_strength = min(1.0, length((wpos - cpos).xyz) * fogmul);
	fog_strength *= fog_strength;

	vec4 color = gl_Color;
	if(gl_TexCoord[0].s >= -0.1)
	{
		vec4 tcolor = texture2D(tex0, gl_TexCoord[0].st);
		color *= tcolor;
	}

	if(gl_ProjectionMatrix[3][3] == 1.0)
	{
		// Skip lighting on orthographics
		gl_FragColor = color;

	} else {
		vec4 camto = vec4(normalize((wpos - cpos).xyz), 0.0);

		// Diffuse
		float diff = max(0.0, dot(-camto, wnorm));
		diff = 0.3 + 1.5*diff; // Exaggerated

		// Specular
		// disabling until it makes sense
		/*
		vec4 specdir = normalize(2.0*dot(wnorm, -sun)*wnorm - -sun);
		float spec = max(0.0, dot(-camto, specdir));
		spec = pow(spec, 32.0)*0.6;
		*/

		//color = vec4(vec3(color.rgb * diff) + vec3(1.0)*spec, color.a);
		diff = diff * (1.0 - fog_strength);
		diff = min(1.5, diff);
		color = vec4(color.rgb * diff, color.a);
		color = max(vec4(0.0), min(vec4(1.0), color));
		//color = vec4(0.5+0.5*sin(3.141593*(color.rgb-0.5)), color.a);

		gl_FragColor = color * (1.0 - fog_strength)
			+ gl_Fog.color * fog_strength;
	}
}
]=]}

