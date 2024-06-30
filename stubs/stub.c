#include "stub.h"
#include <libc/dlopen/dlfcn.h>
#include <stdio.h>

void *try_find_lib(char **candidates, int len) {
    void *lib = NULL;

    for (int i = 0; i < len; ++i)
        if ((lib = cosmo_dlopen(candidates[i], RTLD_LAZY)))
            return lib;

    return NULL;
}

void *try_find_sym(void *lib_ptr, const char *name) {
    void *sym = cosmo_dlsym(lib_ptr, name);

    if (!sym)
        fprintf(stderr, "Unable to resolve symbol %s\n", name);

    return sym;
}
