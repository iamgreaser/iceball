TITLE = ICEBALL_W_VER + " - Command line tutorial"

# this is just a conversion of the guide in READ_THIS_FIRST.txt.

BODY = m_html(m_head(m_title(TITLE)), m_body(
	m_h1(TITLE),
	m_hr(),
	m_p(
		"Now, the first thing you will need to know is how to use the commandline.",
		"If you don't know THAT, here's a quick guide:"
	),
	
	m_p("Stuff on the commandline takes the form:"),
	m_p(m_tt("command argument argument \"argument with spaces in it\" argument")),
	m_p(
		"If the command you're running has no arguments,",
		"you can run it like so:"
	),
	m_ul(
		m_li("On MS-DOS systems, like Windows: ", m_tt("cls")),
		m_li("On UNIX based systems, like Linux: ", m_tt("clear"))
	),
	
	m_p(
		"Basically, the only built-in command you'll need is \"cd\". ",
		"Let's say you were dropped into where you extracted Iceball to on startup, ",
		"and you want to go to the pkg/base/pmf folder, ",
		"you would do this:"
	),
	m_ul(
		m_li("MS-DOS: ", m_tt("cd pkg\\base\\pmf")),
		m_li("UNIX: ", m_tt("cd pkg/base/pmf"))
	),
	
	m_p(
		"(MS-DOS / Windows users only) "
		"If for some reason you extracted Iceball to C:\Program Files\Iceball, ",
		"and you got dropped into some random location on, say, the D: drive, ",
		"you would do this: "
	),
	m_ul(
		m_li(m_tt("c:")),
		m_li(m_tt("cd \"\Program Files\Iceball\"")),
	),
	
	m_p(
		"I'm assuming people using UNIX based systems can work out how it works on ",
		"their system. (Also, typing some of something then pressing TAB helps, too, ",
		"at least for those of you who are using bash as your shell.)"
	),

	m_p(
		"If you would like to know more about how to use the command line, ",
		"use a search engine."
	),

	m_p(
		"UNIX users: \"man\" is a great program. Try \"man ls\", for instance.",
		"Note, for shell builtins, you might want to use \"help\", e.g. \"help cd\".",
	),
	
	m_p(
		"Anyhow, with that sorted, and assuming you're in the Iceball directory now,",
		"type this into the commandline for help:"
	),
	m_ul(
		m_li("MS-DOS: ", m_tt("iceball")),
		m_li("UNIX: ", m_tt("./iceball"))
	),
	
	m_p(
		"You should be fine from there.",
	),
	
	m_p(
		"NOTE: On Windows, you will need to check stderr.txt for the help you need.",
		"I haven't set it up to make SDL *NOT* do this stupid crap yet."
	),
	
	m_p("By the way, here's a tip for the Windows users:"),
	m_p("Double-click opencmd.bat. It should get you into the right directory."),
	
	m_p("If you have any questions, use your preferred search engine.")
))
