TITLE = ICEBALL_W_VER + " - How to play"

BODY = m_html(m_head(m_title(TITLE)), m_body(
	m_h1(TITLE),
	m_hr(),
	m_p(
		m_b("IMPORTANT:"), " This is only accurate for the base mod. ",
		"Any serverside mods may make some of these not apply."
	),
	m_h2("Controls (default)"),
	m_ul(
		m_li("W/A/S/D: move around"),
		m_li("Mouse: look around"),
		m_li("T/Y/U: talk / teamchat / squadchat"),
		m_li("1/2/3/4: switch tool (scrollwheel also works)"),
		m_li("Arrows: change block colour"),
		m_li("Tab: show scores"),
		m_li("M: show map"),
		m_li("R: reload gun"),
	),
	m_h2("Tools"),
	m_ul(
		m_li("1: Spade. ",
		"Left click to break one at a time (can get blocks back like this). ",
		"Right click to break a 3-high pillar (a block above and below the target)."),
		m_li("2: Block. ",
		"Left click to place. Right click to pick a colour. ",
		"Arrow keys will pick a colour from a predefined palette."),
		m_li("3: Gun. ",
		"Left click to shoot. Right click to zoom. ",
		"R to reload. Aim for the head!"),
		m_li("4: Grenade. ",
		"Hold left click to pull pin. Release left click to throw. ",
		"There is a 3 second pin and it CAN explode in your hands. ",
		"Holding longer does NOT make the grenade go further. "),
	),
	m_h2("Etiquette"),
	m_p(
		"Unless the server tells you otherwise, you will be playing as a team. ",
		m_i("This is extremely important."),
		" Whatever colour you are, THAT is who you play for.",
		" If you've forgotten what colour you are, look down."
		" If you can't get on the same team as your friends, ", m_b(m_i("tough."))
	),
	m_p(
		"The server administrators set the rules, not you. ",
		"If a server is empty when you get on, ",
		"this does NOT mean you can declare it to be a build server. ",
	),
	m_p(
		"TODO: More stuff!",
	),
))
