TITLE = ICEBALL_W_VER + " - Licences"

BODY = m_html(m_head(m_title(TITLE)), m_body(
	m_h1(TITLE),
	m_hr(),
	m_p("Iceball (the C engine code) is licensed under the GNU GPL version 3."),
	m_p("Ice Lua Components (the Lua code) is licensed under the GNU Lesser GPL version 3."
	+ " It contains code converted from SDL 1.2, which is licensed under the GNU Lesser GPL version 2.1."),
	m_p("All contributed assets are licensed under",
	m_a("Creative Commons 3.0 Attribution ShareAlike Unported.", href="http://creativecommons.org/licenses/by-sa/3.0/"))
))
