# Taken from https://github.com/vkoskiv/cosmo-sdl-template/blob/master/Makefile

# Get all of the stubs and the headers they contain
STUBS=$(addprefix -I, $(shell find ./stubs/ -maxdepth 2 -type d -not -path '*/X11'))
# Headers in /usr/include
# gtk-4.0 headers in /usr/lib are still needed because of the way they're referenced between eachother
LIBS_RAW=pango-1.0 harfbuzz gdk-pixbuf-2.0 graphene-1.0 cairo gtk-4.0
LIBS=$(addprefix -I/usr/include/, $(LIBS_RAW))
# Headers in /usr/lib
LIBS_2_RAW=graphene-1.0 glib-2.0
LIBS_2=$(addsuffix /include, $(addprefix -I/usr/lib/, $(LIBS_2_RAW)))

CC=cosmocc
CFLAGS=-Wall -Wextra -std=c99 -O0 -Wno-deprecated-declarations $(STUBS) $(LIBS) $(LIBS_2) -DGTK_COMPILATION
LDFLAGS=-ldl
BIN=cosmo-gtk.com
OBJDIR=obj

# Finds all c files but excludes the stubs directory
SRCS=$(shell find . -name "*.c")
OBJS=$(patsubst %.c, $(OBJDIR)/%.o, $(SRCS))

all: $(BIN)

$(OBJDIR)/%.o: %.c $(OBJDIR)
	@mkdir -p '$(@D)'
	@echo "CC $<"
	@$(CC) $(CFLAGS) -c $< -o $@
$(OBJDIR):
	mkdir -p $@
$(BIN): $(OBJS) $(OBJDIR)
	@echo "LD $@"
	@$(CC) $(CFLAGS) $(OBJS) -o $@ $(LDFLAGS)

clean:
	rm -rf obj/* cosmo-gtk.*
