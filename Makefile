# Taken from https://github.com/vkoskiv/cosmo-sdl-template/blob/master/Makefile

CC=cosmocc
CFLAGS=-Wall -Wextra -std=c99 -O0 -I./glib-stub/GLIB                           \
-I/usr/lib/glib-2.0/include -I/usr/include/gtk-4.0/ -I/usr/include/cairo       \
-I/usr/include/pango-1.0 -I/usr/include/harfbuzz -I/usr/include/gdk-pixbuf-2.0 \
-I/usr/include/graphene-1.0 -I/usr/lib/graphene-1.0/include -DGTK_COMPILATION  \
-I./headers
LDFLAGS=-ldl
BIN=cosmo-gtk.com
OBJDIR=obj
SRCS=$(shell find . -name '*.c')
OBJS=$(patsubst %.c, $(OBJDIR)/%.o, $(SRCS))

HEADERS=ffi.h ffitarget.h wayland-client-core.h wayland-client-protocol.h      \
wayland-client.h wayland-cursor.h wayland-egl-backend.h wayland-egl-core.h     \
wayland-egl.h wayland-server-core.h wayland-server-protocol.h wayland-server.h \
wayland-util.h wayland-version.h X11

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

copy_headers:
	mkdir -p ./headers
	cp -r $(addprefix /usr/include/, $(HEADERS)) ./headers
