# cosmo-gtk-template - Maximal GTK sample for Cosmopolitan

This repository contains a full[^1] stub for GTK (and GSK, GDK), GLib, GIO, GObject, GModule, and GIRepository

## Using the Stubs
The stubs folder contains six folders, one for each stub. The necessary headers to build are not present, so run `scripts/copy_headers.sh` to copy the requisite headers into the project.

You should be able to write code as if the stub wasn't even present. During compilation any function calls to the libraries are redirected to the stub (handled by `scripts/postproc.sh`) after macros are expanded by the preprocessor, allowing any GTK and GLib macros to be used as well (Suggestions for improving this redirection would be appreciated as it's a bit of a bodge currently).

If you use Clangd, a script to generate `compile_flags.txt`, `gen_compile_flags.sh`, is present. Run it with the path to cosmopolitan (should contain an include folder). The generated compile_flags.txt should be *mostly* functional.

## Generating the Stub
`generate.lua` in the scripts directory of this repository was used to generate the stub. If you can manage to make it work you can generate them yourself too. This requires lua >= 5.2 (for use of the goto keyword) and [luafilesystem](https://github.com/lunarmodules/luafilesystem).

As a warning, generating the stub will print a little under 50000 lines to your terminal, you may want to redirect them to a file, especially if something goes wrong.

## Dependencies
All of the dependencies of GTK and GLib are required. See the Makefile if you are unsure.

Depending on how you generated the stub, you will need Xlib and wayland-protocol headers.

## References
This repository is based off of vkoskiv's [cosmo-sdl-template](https://github.com/vkoskiv/cosmo-sdl-template). The code used to stub GTK and GLib is largely the same.

[^1]: If anything is missing let me know!
