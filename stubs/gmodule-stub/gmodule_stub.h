#include "glib.h"
#include "gmodule.h"

#ifndef SYMS_GMODULE_H
#define SYMS_GMODULE_H

struct gmodule_syms {
    void *lib;
    // SYMS_gmodule_HERE
    gboolean (*module_supported)(void);
    GModule* (*module_open)(const gchar *file_name, GModuleFlags flags);
    GModule* (*module_open_full)(const gchar *file_name, GModuleFlags flags, GError **error);
    gboolean (*module_close)(GModule *module);
    void (*module_make_resident)(GModule *module);
    const gchar * (*module_error)(void);
    gboolean (*module_symbol)(GModule *module, const gchar *symbol_name, gpointer *symbol);
    const gchar * (*module_name)(GModule *module);
    gchar* (*module_build_path)(const gchar *directory, const gchar *module_name);
    GQuark (*module_error_quark)(void);
};

// DEFINE_STRUCT_HERE


extern struct gmodule_syms *gmodule;
// DEFINE_STRUCT_VAR_HERE
#endif

void initialize_gmodule(void);
void close_gmodule(void);
