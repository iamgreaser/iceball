# I personally don't care if you steal this makefile. --GM

TOOLS = 

SRCDIR = src
INCDIR = include
INCLUDES = $(INCDIR)/common.h
OBJS = \
	$(OBJDIR)/main.o \
	$(OBJDIR)/vecmath.o \
	$(OBJDIR)/map.o $(OBJDIR)/model.o \
	$(OBJDIR)/img.o $(OBJDIR)/render.o $(OBJDIR)/render_img.o \
	$(OBJDIR)/lua.o $(OBJDIR)/network.o \
	$(OBJDIR)/path.o $(OBJDIR)/json.o \
	$(OBJDIR)/wav.o

all: $(BINNAME) $(TOOLS)

clean:
	rm -f $(OBJS)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINNAME): $(OBJDIR) $(OBJS)
	$(CC) -o $(BINNAME) $(LDFLAGS) $(OBJS) $(LIBS)

$(OBJDIR)/lua.o: $(SRCDIR)/lua.c $(SRCDIR)/lua_*.h $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

$(OBJDIR)/%.o: $(SRCDIR)/%.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<


.PHONY: all clean
