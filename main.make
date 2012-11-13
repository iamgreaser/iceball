# I personally don't care if you steal this makefile. --GM

TOOLS = 

INCLUDES = common.h
OBJS = \
	$(OBJDIR)/main.o \
	$(OBJDIR)/vecmath.o \
	$(OBJDIR)/map.o $(OBJDIR)/model.o \
	$(OBJDIR)/img.o $(OBJDIR)/render.o \
	$(OBJDIR)/lua.o $(OBJDIR)/network.o

all: $(OBJDIR) $(BINNAME) $(TOOLS)

clean:
	rm -f $(OBJS)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINNAME): $(OBJS)
	$(CC) -o $(BINNAME) $(LDFLAGS) $(OBJS) $(LIBS)

$(OBJDIR)/%.o: %.c $(INCLUDES)
	$(CC) -c -o $@ $(CFLAGS) $<

