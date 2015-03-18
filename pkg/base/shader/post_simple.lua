return shader_new{name="post_simple", vert=[=[
// Vertex shader

void main()
{
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_TexCoord[0] = gl_MultiTexCoord0;
}

]=], frag=[=[
// Fragment shader

uniform sampler2D tex0;

void main()
{
	vec4 color = texture2D(tex0, gl_TexCoord[0].st);
	color.a = 1.0;
	gl_FragColor = color;
}

]=]}

