# I personally don't care if you steal this makefile. --GM

CFLAGS = -O2 -fno-strict-aliasing -g `sdl-config --cflags` -Wall -Wextra \
	-Wno-unused-variable -Wno-unused-parameter \
	-Wno-unused-but-set-variable

LDFLAGS = -g
LIBS_SDL = `sdl-config --libs`
LIBS_LUA = -llua-5.1
LIBS = -lm $(LIBS_LUA) $(LIBS_SDL) 
BINNAME = bts
TOOL_PMFEDIT = pmfedit
TOOL_PMFEDIT_OBJS = tool_pmfedit.o model.o
TOOLS = $(TOOL_PMFEDIT)

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

$(TOOL_PMFEDIT): $(TOOL_PMFEDIT_OBJS)
	$(CC) -o $(TOOL_PMFEDIT) $(LDFLAGS) $(TOOL_PMFEDIT_OBJS) $(LIBS_SDL)

$(BINNAME): $(OBJS)
	$(CC) -o $(BINNAME) $(LDFLAGS) $(OBJS) $(LIBS)

%.o: %.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

