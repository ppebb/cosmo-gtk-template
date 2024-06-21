# cosmo-gtk-template - Maximal GTK sample for Cosmopolitan

This repository contains a full[^1] stub for GTK, GSK, GDK, GLib (including GIO, GObject, GModule, and GIRepository)

## Building
* Run `make copy_headers` (once ever)
* Run `make`

Due to complications including headers present in /usr/include without accidentally including headers that conflict with cosmopolitan, some headers need to be copied out for this stub to build properly.

## Using the Stub
Within `stubs.tar.gz`, there are two folders, `glib-stub` and `gtk4-stub`, containing the neccessary files to use GTK and GLib from cosmopolitan. Simply untar the archive.

Please note that each stub defines global variables to contain references to the library functions, and should remain as defined within `main.c`.

If you use Clangd, a script to generate `compile_flags.txt`, `gen_compile_flags.sh` is present. Run it with the path to cosmopolitan (should contain an include folder). The generated compile_flags.txt should be *mostly* functional.

## Generating the Stub
`generate.lua` in the root of this repository was used to generate the stub. If you can manage to make it work you can generate them yourself too. This requires lua >= 5.2 (for use of the goto keyword) [luafilesystem](https://github.com/lunarmodules/luafilesystem).

Some options are configurable within the script, check the `defs` table.
* `clear_headers`: Whether the headers copied into the stub should be removed and recopied each run
* `trim-prefix`: Within GTK's header files, functions are prefixed with `gtk_`, `gsk_`, or `gdk_`, enabling this option removes those prefixes so functions can be called as `gtk->init_window()` instead of `gtk->gtk_init_window()`
* `skip_dirs`: List of directories to skip generating the stub for. This can be used to ignore GDK wayland or X11 if you don't need them, for example. These are relative to the directory within the stub containing the header files, so to ignore GDK X11 simply put "x11"

## Dependencies
All of the dependencies of GTK and GLib are required. See the Makefile if you are unsure.

Depending on how you generated the stub, you will need Xlib and wayland-protocol headers. The Makefile will copy these headers into the headers directory

[^1]: Macros (as they don't reference the stub) are not usable, some functions may be missing, functions defined by macros are *definitely* missing. Most everything you need should be in here, and if something is missing let me know!
