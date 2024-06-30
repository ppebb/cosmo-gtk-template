# Taken from https://github.com/vkoskiv/cosmo-sdl-template/blob/master/Makefile

# Get all of the stubs and the headers they contain
STUBS=$(addprefix -I, $(shell find ./stubs/ -maxdepth 1 -type d))
# Headers in /usr/include
LIBS_RAW=pango-1.0 harfbuzz gdk-pixbuf-2.0 graphene-1.0 cairo gtk-4.0 glib-2.0
LIBS=$(addprefix -I/usr/include/, $(LIBS_RAW))
# Headers in /usr/lib
LIBS_2_RAW=graphene-1.0 glib-2.0
LIBS_2=$(addsuffix /include, $(addprefix -I/usr/lib/, $(LIBS_2_RAW)))

CC=cosmocc
CFLAGS=-Wall -Wextra -std=c99 -O0 -Wno-deprecated-declarations $(STUBS) $(LIBS) $(LIBS_2)
LDFLAGS=-ldl
BIN=cosmo-gtk.com
PROCDIR=proc
OBJDIR=obj

# Finds all c files but excludes the headers directory
SRCS=$(shell find . -name "*.c" -not -path '*/headers/*' -and -not -path '*/$(PROCDIR)/*')
OBJS=$(patsubst %.c, $(OBJDIR)/%.o, $(SRCS))

.PHONY: all
all: $(BIN)

$(OBJDIR):
	@mkdir -p $@

$(OBJDIR)/%.o: %.c $(OBJDIR)
	@mkdir -p '$(@D)'
	@echo "CC $<"
	@$(CC) $(CFLAGS) -o $@ -c $<

$(BIN): $(OBJS) $(OBJDIR)
	@echo "LD $@"
	@$(CC) $(CFLAGS) $(OBJS) -o $@ $(LDFLAGS)

.PHONY: clean
clean:
	rm -rf $(PROCDIR) $(OBJDIR) cosmo-gtk.*
