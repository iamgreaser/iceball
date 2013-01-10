TITLE = ICEBALL_W_VER + " - Lua API - fetch"

SECTIONS = [
	(["obj"], "common.fetch_start", ["ftype", "fname"], [], True,
	[m_p("initiates a file fetch"),
	m_p("\"ftype\" is one of the following:"),
	m_ul(
		m_li(m_b("\"lua\":"), "lua script"),
		m_li(m_b("\"map\":"), "map (autodetect)"),
		m_li(m_b("\"icemap\":"), "map (icemap) - in-memory maps are serialised as THIS."),
		m_li(m_b("\"vxl\":"), "map (vxl) - ", m_b("CANNOT SAVE IN THIS FORMAT.")),
		m_li(m_b("\"pmf\":"), "pmf model"),
		m_li(m_b("\"tga\":"), "tga image"),
		m_li(m_b("\"json\":"), "json data"),
		m_li(m_b("\"wav\":"), "wav sound")
	),
	m_p("for the server, this just loads the file from the disk."),
	m_p("for the client, all clsave/* stuff is taken from the disk, ",
	"but all other files are downloaded from the server."),
	
	m_p("returns"),
	m_ul(
		m_li(m_tt(m_b("true")), " if the fetch has started,"),
		m_li(m_tt(m_b("nil")), " if there is an error, or"),
		m_li("the requested object if this was an immediate load.")
	),
	
	m_p("if there is already a file in the queue, ",
	"this will return ", m_tt(m_b("nil")), ".")
	]),
	
	(["obj", "csize", "usize", "amount"], "common.fetch_poll", [], [], True,
	[m_p("polls the status of the file being currently tranferred,"
	"if it exists."),
	
	m_p("\"obj\" is one of the following:"),
	m_ul(
		m_li(m_tt(m_b("nil")), " if transfer aborted or nothing is being fetched"
			, " - in this case, all other fields will be ",m_tt(m_b("nil"))),
		m_li(m_tt(m_b("false")), " if still downloading"),
		m_li("the object you requested"
			, " - in this case, another poll will just return nil"),
	),
	
	
	m_p("\"amount\" is in the range 0 <= \"amount\" <= 1, ",
	"and indicates how much is downloaded"),
	m_p("\"csize\" is the compressed size of the file"),
	m_p("\"usize\" is the uncompressed size"),
	
	m_p("the two sizes will be nil while unknown."),
	
	m_p("note, all vxl maps will be converted to icemap before sending.")]),
	
	(["obj"], "common.fetch_block", ["ftype", "fname"], [], True,
	[m_p("fetches a file using common.fetch_*"),
	m_p("simply returns ", m_tt(m_b("nil")), " on error "),
	m_p("if there is already something being fetched,",
	"it will return ", m_tt(m_b("nil")), ", too"),]),
]
"""
obj = common.fetch_block(ftype, fname) @
	fetches a file using common.fetch_*
	
	simply returns "nil" on error
	
	if there is already something being fetched,
	it will return "nil", too
"""

BODY = m_html(m_head(m_title(TITLE)), m_body(*([
	m_h1(TITLE),
	m_hr()] +
	gen_lua_api_docs(SECTIONS)
)))
