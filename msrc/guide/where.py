TITLE = ICEBALL_W_VER + " - What goes where"

BODY = m_html(m_head(m_title(TITLE)), m_body(
	m_h1(TITLE),
	m_hr(),
	m_h2("Security notes"),
	m_p(
		"Clients, ", m_b("NEVER TRUST THE SERVER."),
		" Furthermore, putting stuff in clsave/(mod name)/ and clsave/(mod name)/vol/ ",
		"does NOT protect against attacks that can be done to clsave/pub/ and clsave/vol/.",
	),
	m_p(
		"Servers, I suggest you check your code for anything dodgy. ",
		"Also, you can safely put mod-private stuff in svsave/(mod name)/, ",
		"provided the mod code doesn't suck (this is NOT the case for the client)."
	),
	m_h2("Paths"),
	m_ul(
		m_li(m_b(m_tt("clsave/"),":"), " This is where \"local\" files go."),
		m_li(m_b(m_tt("clsave/pub/"),":"), " This is where you put local files to be readable by all mods."),
		m_li(m_b(m_tt("clsave/vol/"),":"), " This is where you put local files to be writeable by all mods. "
			, m_b("This folder is dangerous. Be careful!")),
		m_li(m_b(m_tt("clsave/(mod name)/"),":"), " This is where you put local files to be readable by one mod."),
		m_li(m_b(m_tt("clsave/(mod name)/vol/"),":"), " This is where you put local files to be writeable by one mod."
			, m_b("This folder is actually just as dangerous. Be careful!")),
		m_li(m_b(m_tt("pkg/"),":"), " This is where server mods go. All files here are globally readable."),
		m_li(m_b(m_tt("pkg/maps/"),":"), " This is the recommended place to stash maps."),
		m_li(m_b(m_tt("pkg/base/"),":"), " This is the folder for the base mod."),
		m_li(m_b(m_tt("pkg/(group name)/(mod name)/"),":"),
			" This is the folder scheme for any mods that aren't the base mod."),
		m_li(m_b(m_tt("svsave/"),":"), " This is where server-local files go."),
		m_li(m_b(m_tt("svsave/pub/"),":"), " This is where you put server-local files to be readable by all mods."),
		m_li(m_b(m_tt("svsave/vol/"),":"), " This is where you put server-local files to be writeable by all mods."
			, m_b("This folder is as dangerous as your mods are. Check your code!")),
		m_li(m_b(m_tt("svsave/(mod name)/"),":"), " This is where you put server-local files to be readable by one mod."),
		m_li(m_b(m_tt("svsave/(mod name)/vol/"),":"), " This is where you put server-local files to be writeable by one mod."
			, m_b("This folder is as dangerous as your mods are. Check your code!"))
	)
))
