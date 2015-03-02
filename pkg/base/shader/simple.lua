return shader_new{name="simple", vert=[=[
// Vertex shader

void main()
{
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
	gl_FrontColor = gl_Color;
}

]=], frag=[=[
// Fragment shader

void main()
{
	gl_FragColor = gl_Color;
}
]=]}

