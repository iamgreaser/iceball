# I personally don't care if you steal this makefile. --GM

TOOLS = 

ifndef RENDERER
RENDERER = gl
endif

SRCDIR = src
INCDIR = include
INCLUDES = $(INCDIR)/common.h
OBJS = \
	$(OBJDIR)/main.o \
	$(OBJDIR)/vecmath.o \
	$(OBJDIR)/dsp.o \
	$(OBJDIR)/map.o $(OBJDIR)/model.o \
	$(OBJDIR)/img.o $(OBJDIR)/$(RENDERER)/render.o $(OBJDIR)/$(RENDERER)/render_img.o \
	$(OBJDIR)/png.o \
	$(OBJDIR)/lua.o $(OBJDIR)/network.o \
	$(OBJDIR)/path.o $(OBJDIR)/json.o \
	$(OBJDIR)/wav.o

# TODO: make the renderer part not depend on, say, render_img.o

all: $(BINNAME) $(TOOLS)

clean:
	rm -f $(OBJS)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/$(RENDERER):
	mkdir -p $(OBJDIR)/$(RENDERER)

$(BINNAME): $(OBJDIR) $(OBJDIR)/$(RENDERER) $(OBJS)
	$(CC) -o $(BINNAME) $(LDFLAGS) $(OBJS) $(LIBS)

$(OBJDIR)/lua.o: $(SRCDIR)/lua.c $(SRCDIR)/lua_*.h $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

$(OBJDIR)/$(RENDERER)/%.o: $(SRCDIR)/$(RENDERER)/%.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

$(OBJDIR)/%.o: $(SRCDIR)/%.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<


.PHONY: all clean

