#include "glib-stub/glib_stub.h"
#include "gtk4-stub/gtk4_stub.h"

struct gtk_syms *gtk;
struct glib_syms *glib;

int main(void) {
    try_initialize_gtk();
    try_initialize_glib();

    GtkWidget *window;

    gtk->init();

    window = gtk->window_new();

    gtk->window_present((GtkWindow *)window);

    while (true)
        glib->main_context_iteration(NULL, true);

    close_gtk();
    close_glib();

    return 0;
}
