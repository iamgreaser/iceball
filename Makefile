# I personally don't care if you steal this makefile. --GM

CFLAGS = -pg -O2 -fno-strict-aliasing -g `sdl-config --cflags` -Wall -Wextra \
	-Wno-unused-variable -Wno-unused-parameter \
	-Wno-unused-but-set-variable

LDFLAGS = -pg -g
LIBS_SDL = `sdl-config --libs`
LIBS_LUA = -llua-5.1
LIBS = -lm $(LIBS_LUA) $(LIBS_SDL) 
BINNAME = iceball
TOOLS = 

INCLUDES = common.h
OBJS = \
	main.o \
	vecmath.o \
	map.o model.o \
	render.o \
	lua.o network.o

all: $(BINNAME) $(TOOLS)

clean:
	rm -f $(OBJS)

$(BINNAME): $(OBJS)
	$(CC) -o $(BINNAME) $(LDFLAGS) $(OBJS) $(LIBS)

%.o: %.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

