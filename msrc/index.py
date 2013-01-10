TITLE = ICEBALL_W_VER + " Manual"

SECTIONS = [
	("Contents", "", [
		("Changelog", "main/changelog", None),
		("Credits", "main/credits", None),
		("Licences", "main/lic", None),
		("System requirements", "main/req", None),
		("Important Tutorials", "tut/", [
			(m_b(m_i("READ THIS FIRST")), "rtfm", None),
			("Command line tutorial", "cmd", None),
			("JSON tutorial", "json", None),
			("Compiling the engine", "compile", None),
			("How to play", "play", None),
		]),
		("Users' Guide", "guide/", [
			("What goes where", "where", None),
			("Engine config (clsave/config.json)", "config", None),
			("User config (clsave/pub/user.json)", "user", None),
			("Controls (clsave/pub/controls.json)", "controls", None),
			("Command line arguments", "args", None),
		]),
		("Utilities", "util/", [
			("mapedit", "mapedit", None),
			("pmfedit", "pmfedit", None),
		]),
		("Modding The Game", "mods/", [
			("Coding conventions", "conv", None),
			("Networking protocol", "network", None),
			("Base game API", "base/", [
				("Preloader", "preload", None),
				("Libraries", "lib", None),
			]),
			("Lua API reference", "lua/", [
				("Notes", "notes", None),
				("Sections", "sect/", [
					("Function hooks", "hook", None),
					("camera", "camera", None),
					("fetch", "fetch", None),
					("image", "image", None),
					("json", "json", None),
					("map", "map", None),
					("model", "model", None),
					("mouse", "mouse", None),
					("net", "net", None),
					("wav", "wav", None),
				]),
			]),
		]),
		("File Formats", "fmt/", [
			("[vxl] Ace of Spades Map", "vxl", None),
			("[icemap] IceMap", "icemap", None),
			("[tga] Targa Image", "tga", None),
			("[pmf] Point Model Format", "pmf", None),
			("[json] JavaScript-Oriented Notation", "json", None),
			("[wav] Wave Audio", "wav", None),
		]),
	])
]

BODY = m_html(m_head(m_title(TITLE)), m_body(*([
	m_h1(TITLE),
	m_hr(),
	m_p(
		"NOTE: the HTML documentation is incomplete. Sorry guys. ",
		"It should be mostly there by 0.1."
	)] +
	gen_list(SECTIONS, level=2)
)))
