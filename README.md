# cosmo-gtk-template - Maximal GTK sample for Cosmopolitan

This repository has been superceded by a general purpose tool, [cosmo-stub-generator](https://github.com/ppebb/cosmo-stub-generator). Use it instead.

This repository contains a full[^1] stub for GTK (and GSK, GDK), GLib, GIO, GObject, GModule, and GIRepository

## Using the Stubs
The stub contains two folders, one for GLib and one for GTK located in the `stubs` folder. The necessary headers to build are not present, so run `scripts/copy_headers.sh` to copy the requisite headers into the `stubs` folder.

Simply copy the `stubs` folder into your project and import `glib_stub.h` or `gtk_stub.h`.

If you use Clangd, a script to generate `compile_flags.txt`, `gen_compile_flags.sh`, is present. Run it with the path to cosmopolitan (should contain an include folder). The generated compile_flags.txt should be *mostly* functional.

## Generating the Stub
`generate.lua` in the scripts directory of this repository was used to generate the stub. If you can manage to make it work you can generate them yourself too. This requires lua >= 5.2 (for use of the goto keyword) and [luafilesystem](https://github.com/lunarmodules/luafilesystem).

The only real configurable option is `set_guard_function_calls` in `scripts/generate.lua`. By changing the value in the function call to true, it will generate every function call with a null check, printing a message to stderr if it is null This does not prevent a segfault, it just makes debugging a little bit easier. Do not use this option for a release binary as it nearly doubles the size of the compiled binary.

As a warning, generating the stub will print a little under 50000 lines to your terminal, you may want to redirect them to a file, especially if something goes wrong.

## Dependencies
All of the dependencies of GTK and GLib are required. See the Makefile if you are unsure.

Depending on how you generated the stub, you will need Xlib and wayland-protocol headers.

## References
This repository is based off of vkoskiv's [cosmo-sdl-template](https://github.com/vkoskiv/cosmo-sdl-template). The code used to stub GTK and GLib is largely the same.

[^1]: Certain functions making use of variadic arguments do not have an equivalent function which takes a `va_list`. As a result the arguments passed using `...` cannot be forwarded to the stubbed function.
