# I personally don't care if you steal this makefile. --GM

CFLAGS = -pg -O2 -fno-strict-aliasing -g `sdl-config --cflags` -Wall -Wextra \
	-Wno-unused-variable -Wno-unused-parameter \
	-Wno-unused-but-set-variable $(CFLAGS_EXTRA) \
	-fopenmp \
	-I $(INCDIR) -Ixlibinc \
	$(HEADERS_Lua)

# Uncomment this if you are Debian or Debian-derived
HEADERS_Lua = #-I /usr/include/lua5.1

LDFLAGS = -pg -g $(LDFLAGS_EXTRA) -fopenmp
LIBS_SDL = `sdl-config --libs`
LIBS_ENet = xlibinc/libenet.a
LIBS_Lua = -llua
# Lua is not an acronym. Get used to typing it with lower case u/a.
LIBS_zlib = -lz
LIBS_sackit = -lsackit
LIBS = -Lxlibinc -lm $(LIBS_Lua) $(LIBS_SDL) $(LIBS_zlib) $(LIBS_sackit) $(LIBS_ENet)

BINNAME = iceball

OBJDIR = build/unix

include main.make
