#!/bin/sh

# Because EVERY DISTRO JUST HAS TO INSIST ON DOING IT DIFFERENTLY
# IT'S LIKE THESE MORONS DON'T KNOW WHAT STANDARDS ARE

if pkg-config luajit ; then
	pkg-config luajit $@
elif pkg-config lua-5.1 ; then
	# FreeBSD
	pkg-config lua-5.1 $@
elif pkg-config lua5.1 ; then
	# Debian
	pkg-config lua5.1 $@
elif pkg-config lua51 ; then
	# Arch
	pkg-config lua51 $@
elif pkg-config lua --atleast-version 5.1 --max-version 5.1.9999 ; then
	# Slackware?
	pkg-config lua $@
else
	echo Lua 5.1 not found - tweak findlua.sh to suit your liking. 1>&2
	echo Note, Iceball does not support Lua 5.2. 1>&2
fi
