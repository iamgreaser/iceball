# HTML doc generator by GreaseMonkey, 2013. Public domain.
# Contents of said manual are also public domain, except where otherwise specified.

import os

ICEBALL_W_VER = "Iceball (pre-)0.1"

def mktag(name):
	def _f1(*args, **kwargs):
		s = "<" + name
		for k in kwargs:
			v = kwargs[k]
			s += " " + k + "=\"" + v + "\""
			# TODO: ensure this remains valid HTML
		
		if len(args) == 0:
			s += " />"
			return s
		
		s += ">"
		
		for v in args:
			s += "\n" + v
		
		s += "\n</" + name + ">"
		return s
	
	return _f1

m_html = mktag("html")
m_head = mktag("head")
m_title = mktag("title")
m_body = mktag("body")
m_hr = mktag("hr")

m_h1 = mktag("h1")
m_h2 = mktag("h2")
m_h3 = mktag("h3")
m_h4 = mktag("h4")
m_h5 = mktag("h5")
m_h6 = mktag("h6")
mgrp_h = [m_h1, m_h2, m_h3, m_h4, m_h5, m_h6]

m_p = mktag("p")
m_ul = mktag("ul")
m_li = mktag("li")

m_b = mktag("b")
m_i = mktag("i")
m_u = mktag("u")
m_tt = mktag("tt")

m_a = mktag("a")

def mkpage(name):
	print "Generating", name
	try:
		nl = name.split("/")
		if len(nl) > 1:
			os.makedirs("MANUAL/" + "/".join(nl[:-1]))
		else:
			os.makedirs("MANUAL")
	except OSError:
		pass
	
	BODY = None
	
	try:
		fp = open("msrc/" + name + ".py", "rb")
		exec fp.read().replace("\r\n","\n").replace("\r","")
		fp.close()
	except IOError:
		print "ERROR:", name, "- IOError"
		return False
	
	fp = open("MANUAL/" + name + ".html", "wb")
	fp.write(BODY.replace("\n","\r\n"))
	fp.close()
	return True

def gen_list(l, pbase="", level=1):
	ul_data = None
	list_data = []
	for name, page, sl in l:
		if sl:
			if ul_data != None:
				list_data.append(m_ul(*ul_data))
				ul_data = None
			list_data.append(mgrp_h[level-1](name))
			list_data += gen_list(sl, pbase if page == None else pbase + page, level+1)
		else:
			if ul_data == None:
				ul_data = []
			pg_pass = page != None and mkpage(pbase + page)
			licontent = name if not pg_pass else m_a(name, href = pbase + page + ".html")
			ul_data.append(m_li(licontent))
	
	if ul_data != None:
		list_data.append(m_ul(*ul_data))
	
	return list_data

def gen_lua_api_docs(l):
	list_data = []
	for rets, name, args, optargs, isimp, tags in l:
		s = name + "("
		
		if rets:
			s = ", ".join(rets) + " = " + s
		l2 = []
		for n in args:
			l2.append(n)
		
		for n, v in optargs:
			l2.append(n + " = " + v)
		
		s += ", ".join(l2) + "):"
		list_data.append(m_h2(m_tt(s)))
		list_data += tags
	
	return list_data

mkpage("index")
