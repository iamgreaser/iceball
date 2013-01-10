TITLE = ICEBALL_W_VER + " - Credits"

SECTIONS = [
	("GreaseMonkey", None, [
		("Lead developer", None, [
			("Everything other people didn't. Note, some stuff might not be listed below. Totally my fault.", None, None),
		])
	]),
	
	#
	# AND THE REST IN ALPHABETICAL ORDER
	#
	("Arctic77", None, [
		("Modeller", None, [
			("Rifle model added January 2013", None, None),
		])
	]),
	
	("BR", None, [
		("Game programmer", None, [
			("Player name list", None, None),
			("Team switching", None, None),
			("\"Are you sure?\" on quit", None, None),
			("Improved key binding system", None, None),
		])
	]),
	
	("Dany0", None, [
		("Beginning contributor", None, [
			("Czech translation", None, None),
		])
	]),
	
	("Ericson2314 / SonarPulse", None, [
		("Engine programmer", None, [
			("Rearranged the build tree", None, None),
			("Added a SIMD-optimised matrix-vector multiply (not used at the moment)", None, None),
		])
	]),
	
	("rakiru", None, [
		("Game programmer", None, [
			("Scroll wheel to switch tools", None, None),
			("Lent his VPS to host an Iceball server", None, None),
		])
	]),
	
	("topo", None, [
		("Minor contributor", None, [
			("FPS counter", None, None),
			("Basic key binding system (now obsoleted)", None, None),
		])
	]),
	
	("Triplefox", None, [
		("Game programmer", None, [
			("Widget system", None, None),
			("Miscellaneous utility functions", None, None),
			("Author of pkg/maps/mesa.vxl", None, None),
		])
	]),
	
	("UnrealIncident", None, [
		("Minor contributor", None, [
			("Debug info (which is the reason we use string.format at all)", None, None),
		])
	]),
]

BODY = m_html(m_head(m_title(TITLE)), m_body(*([
	m_h1(TITLE),
	m_hr()] +
	gen_list(SECTIONS, level=2)
)))
