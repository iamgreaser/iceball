return shader_new{name="white", vert=[=[
// Vertex shader

void main()
{
	gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
}

]=], frag=[=[
// Fragment shader

void main()
{
	gl_FragColor = vec4(1.0);
}
]=]}

