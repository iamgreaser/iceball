TITLE = ICEBALL_W_VER + " - Changelog"

SECTIONS = [
	("0.1", None, [
		("Initial release.", None, None),
	]),
]

BODY = m_html(m_head(m_title(TITLE)), m_body(*([
	m_h1(TITLE)] +
	gen_list(SECTIONS, level=2)
)))
