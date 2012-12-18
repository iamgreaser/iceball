# I personally don't care if you steal this makefile. --GM

CFLAGS = -pg -O2 -fno-strict-aliasing -g `sdl-config --cflags` -Wall -Wextra \
	-Wno-unused-variable -Wno-unused-parameter \
	-Wno-unused-but-set-variable $(CFLAGS_EXTRA) \
	-I $(INCDIR) \
	$(HEADERS_LUA)

# Uncomment this if your are are Debian or Debian-derived
HEADERS_LUA = #-I /usr/include/lua5.1

LDFLAGS = -pg -g $(LDFLAGS_EXTRA)
LIBS_SDL = `sdl-config --libs`
LIBS_Lua = -llua
# Lua is not an acronym. Get used to typing it with lower case u/a.
LIBS_zlib = -lz
LIBS = -lm $(LIBS_Lua) $(LIBS_SDL) $(LIBS_zlib)

BINNAME = iceball

OBJDIR = build/unix
SRCDIR = src
INCDIR = include


include main.make
