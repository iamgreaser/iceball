return shader_new{name="img", vert=[=[
// Vertex shader

void main()
{
	// use ProjectionMatrix otherwise text printing breaks
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	//gl_Position = gl_ModelViewMatrix * gl_Vertex;
	gl_FrontColor = gl_Color;
	gl_TexCoord[0] = gl_MultiTexCoord0;
}

]=], frag=[=[
// Fragment shader

uniform sampler2D tex0;

void main()
{
	vec4 color = gl_Color;
	vec4 tcolor = texture2D(tex0, gl_TexCoord[0].st);
	color *= tcolor;
	gl_FragColor = color;
}

]=]}

