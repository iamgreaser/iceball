TITLE = ICEBALL_W_VER + " - Lua API - camera"

SECTIONS = [
	(None, "client.camera_point", ["dx", "dy", "dz"], [("zoom", "1.0"), ("roll", "0.0")], True,
	[m_p("points the camera in a direction with zoom factor \"zoom\"",
	"and roll \"roll\" (in radians, sorry)")]),
	
	(None, "client.camera_point_sky", ["dx", "dy", "dz"], [("zoom", "1.0"), ("sx", "0.0"), ("sy", "-1.0"), ("sz", "0.0")], True,
	[m_p("points the camera in a direction with zoom factor \"zoom\"",
	"and sky arrow sx,sy,sz")]),
	
	(None, "client.camera_move_local", ["dx", "dy", "dz"], [], True,
	[m_p("moves the camera in the camera-local direction (dx,dy,dz)")]),
	
	(None, "client.camera_move_global", ["dx", "dy", "dz"], [], True,
	[m_p("moves the camera in the world direction (dx,dy,dz)")]),
	
	(None, "client.camera_move_to", ["px", "py", "pz"], [], True,
	[m_p("moves the camera to the world position (px,py,pz)")]),
	
	(["px", "py", "pz"], "client.camera_get_pos", [], [], True,
	[m_p("gets the camera's position")]),
	
	(["dx", "dy", "dz"], "client.camera_get_forward", [], [], True,
	[m_p("gets the camera's forward vector")]),
]

BODY = m_html(m_head(m_title(TITLE)), m_body(*([
	m_h1(TITLE),
	m_hr()] +
	gen_lua_api_docs(SECTIONS)
)))
