TITLE = ICEBALL_W_VER + " - READ THIS OR I WILL SEND YOUR PET TO THE TRASH COMPACTOR AND FEED THE MEAT TO YOUR KIDS"

BODY = m_html(m_head(m_title(TITLE)), m_body(
	m_h1(TITLE),
	m_hr(),
	
	#
	#
	#
	m_h2("Congratulations!"),
	m_p(
		"You've just extracted Iceball from its archive into a folder somewhere! ",
		"(which I ", m_i("seriously"), " hope wasn't straight into your desktop) ",
		"What's more, you've probably double-clicked on it, wondered what the hell ",
		"was going on, and decided to ", m_i("confess your ultimate noobiness"),
		" and ", "<i>read the fu</i><tt>^H^H</tt> <i><b>fine</b> manual.</i>",
	),
	m_p(
		"So what the hell is going on, you ask? Well, if you'd simply opened Iceball ",
		"in a command line like a ", m_i("true power user,"), " you would have noticed ",
		"that you need to punch in a few ", m_i("command line arguments."),
		" Then, as a responsible power user, you'd come and read the manual as you have ",
		"no clue what key does what, and you'd be wondering how to set your name."
	),
	m_p(
		"So, power user or not, your ultimate destiny is ", m_i("this very manual.")
	),
	
	#
	#
	#
	m_h2("So what do I do?"),
	m_p(
		"Read through the Users' Guide. ",
		"You also have this sudden urge to read up on \"How to play\", ",
		"and to read it intently. "
	),
	m_p(
		"If you're a competent enough user to not use Windows or Mac OS, ",
		"you may also need to read the \"Compiling the engine\" section."
	),
	m_p(
		"If you suck at using a command line and suck at using JSON, ",
		"there are short tutorials for them. ",
		"There's also a complete specification of the JSON syntax. ",
	),
	
	#
	#
	#
	m_h2("Can you give me a TL;DR?"),
	m_p(
		"Sure. ", m_a(m_b(m_i("RTFM.")), title="READ THE FUCKING MANUAL",
			style="cursor: pointer"),
	),
	
	#
	#
	#
	m_h2("But it's too hard! Can't you just make it easier to use?"),
	m_p(
		"We need to have a barrier to entry to the level of ",
		"\"you must read the manual\". This is because there are important ",
		"things we need to communicate, most boil down to ",
		"\"don't be a stupid idiot\". "
	),
	m_p(
		"If it's too hard, either we need better documentation, ",
		"or we need a better you."
	),
	
	#
	#
	#
	m_h2("I'll just make a tool to make it really easy to..."),
	m_p(
		m_b("Don't do that."),
	),
	m_p(
		"Seriously. You're going against the design decisions we (read: I) have made.",
		"If you want to make it easier, contribute better documentation."
	),
	
	#
	#
	#
	m_h2("This game sucks because (insert reason here)"),
	m_p(
		"Iceball is Free Software. ",
		"You have the right to modify the code and assets, ",
		"provided it remains under the appropriate licence. ",
		"Furthermore, if you're talking about the game, rather than the engine, ",
		"you can just update these on your server."
	),
	m_p(
		"If you'd like your improvements to be included, ",
		"feel free to send us a patch."
	),
	m_p(
		"Note, there is a strict NO SMG POLICY. ",
		"If you don't like it, pay your $10 to Jagex and leave us alone."
	),
	
	#
	#
	#
	m_h2("This game is too hard! I'll just browse MPGH and..."),
	m_p(
		m_b("Hold the phone."),
	),
	m_p(
		"While I do accept that hacking is a fun, educational exercise, ",
		"I must also tell you that if you don't do the hard yards of actually ",
		m_i("developing"), " the hack, you are a bludger and bad for society. ",
		"Go read more books. Hopefully that'll stop you from being so whingy."
	),
	m_p(
		"Anyhow, my plea is this.",
	),
	m_p(
		"Please do not release your hacks publically. ",
		"Sure, you might get reputation when people go \"THANK YOU!!!!!1 YOUR THE BEST\", ",
		"but these script kiddies will, um, not be able to say ",
		"\"Hey guys, check out this hack by &#8592;&#8592;&#8592;xXkillerXx!\". ",
		"Instead, they will downplay it as \"skill\". ",
		"These are the most whingy little kids I've ever had to deal with, ",
		"and I utterly hate dealing with them. ",
		"And once your hack is patched, ", m_i("YOU"), " will be dealing with them instead. ",
		"Algeum polak?"
	),
	m_p(
		m_b("If you release your hacks publically, we will put your IP ranges in the Git code,"
		+ " and you and some of your closest friends will be permanently banned from this game. ",
		m_i("Those people you take down will probably not be your friends anymore.")),
	),
	m_p(
		m_b("If you decide to hack this game, or if you use any public hacks, ",
		"expect to be banned from lots of servers. ",
		"There is absolutely NO warranty, ESPECIALLY if someone decides to ",
		"detect your hack and scar you for life.")
	),
	m_p(
		"While I would say \"you have been warned\", ",
		m_i("you do not ", m_b("deserve"), " to be warned."),
		" This warning is about as far as I will extend my grace."
	),
))
