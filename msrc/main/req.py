TITLE = ICEBALL_W_VER + " - System requirements"

BODY = m_html(m_head(m_title(TITLE)), m_body(
	m_h1(TITLE),
	m_hr(),
	m_h2("Client:"),
	m_h3("Required:"),
	m_ul(
		m_li("CPU: Any 32-bit x86 CPU with SSE2 support",
			" (you could do a non-SSE2 build, but if you need it, your computer's too slow)"
			" (also, if you're doing a non-x86 build, please get in touch with us!)"),
		m_li("RAM: 128MB (you COULD try 64MB, but that's REALLY pushing it)"),
		m_li("OS: Windows 2000 / Linux 2.6 (possibly even earlier)"),
		m_li("GPU: Anything with a framebuffer that can handle 800x600 windows")
	),
	m_h3("Recommended:"),
	m_ul(
		m_li("CPU: Any x86-64 dual-core CPU >= 2GHz (it's not multithreaded yet, but dual core helps)"),
		m_li("RAM: As much RAM as you're willing to throw at it"),
		m_li("OS: Linux 2.6")
	),
	m_h2("Server:"),
	m_h3("Required:"),
	m_ul(
		m_li("CPU: Any little-endian CPU"),
		m_li("RAM: 64MB (32MB is pushing it, plus we have memory leaks right now so even 64MB is pushing it a bit)"),
		m_li("OS: Linux 2.6")
	),
	m_h3("Recommended:"),
	m_ul(
		m_li("CPU: Any ", m_b("real"), " little-endian CPU (read: not a VPS)"),
		m_li("RAM: As much RAM as you're willing to throw at it"),
		m_li("OS: Linux 2.6")
	),
	m_h2("User:"),
	m_h3("Required:"),
	m_ul(
		m_li("A brain that can pick up patterns and actually listen to people")
	)
))
