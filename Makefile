# I personally don't care if you steal this makefile. --GM

CFLAGS = -pg -O2 -fno-strict-aliasing -g `sdl-config --cflags` -Wall -Wextra \
	-Wno-unused-variable -Wno-unused-parameter \
	-Wno-unused-but-set-variable $(CFLAGS_EXTRA)

LDFLAGS = -pg -g $(LDFLAGS_EXTRA)
LIBS_SDL = `sdl-config --libs`
LIBS_Lua = -llua
# Lua is not an acronym. Get used to typing it with lower case u/a.
LIBS = -lm $(LIBS_Lua) $(LIBS_SDL) 
BINNAME = iceball

OBJDIR = build/unix

include main.make
