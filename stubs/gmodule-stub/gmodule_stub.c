// Based on vkoskiv's cosmo-sdl-template under the MIT license.
// See https://github.com/vkoskiv/cosmo-sdl-template/
// See https://github.com/vkoskiv/cosmo-sdl-template/blob/master/LICENSE

#include "gmodule_stub.h"
#include "../stub.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#define _COSMO_SOURCE
#include <libc/dlopen/dlfcn.h>

void initialize_gmodule(void) {
    char* candidates[] = { "libgmodule-2.0.so" };

    void *gmodule_lib_ptr = try_find_lib(candidates, LEN(candidates));

    if (!gmodule_lib_ptr) {
        fprintf(stderr, "Unable to locate gmodule, exiting!");
        exit(1);
    }

    gmodule = calloc(1, sizeof(*gmodule));
    *gmodule = (struct gmodule_syms) {
        .lib = gmodule_lib_ptr,
        // DLSYM_gmodule_HERE
        .module_supported = try_find_sym(gmodule_lib_ptr, "g_module_supported"),
        .module_open = try_find_sym(gmodule_lib_ptr, "g_module_open"),
        .module_open_full = try_find_sym(gmodule_lib_ptr, "g_module_open_full"),
        .module_close = try_find_sym(gmodule_lib_ptr, "g_module_close"),
        .module_make_resident = try_find_sym(gmodule_lib_ptr, "g_module_make_resident"),
        .module_error = try_find_sym(gmodule_lib_ptr, "g_module_error"),
        .module_symbol = try_find_sym(gmodule_lib_ptr, "g_module_symbol"),
        .module_name = try_find_sym(gmodule_lib_ptr, "g_module_name"),
        .module_build_path = try_find_sym(gmodule_lib_ptr, "g_module_build_path"),
        .module_error_quark = try_find_sym(gmodule_lib_ptr, "g_module_error_quark"),
    };

// INIT_STRUCT_HERE

}

void close_gmodule(void) {
    cosmo_dlclose(gmodule->lib);
    free(gmodule);
}
