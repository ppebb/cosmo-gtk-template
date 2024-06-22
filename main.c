#include "gio-stub/gio_stub.h"
#include "gir-stub/gir_stub.h"
#include "glib-stub/glib_stub.h"
#include "gmodule-stub/gmodule_stub.h"
#include "gobject-stub/gobject_stub.h"
#include "gtk4-stub/gtk4_stub.h"

struct gtk_syms *gtk;
struct gdk_syms *gdk;
struct gsk_syms *gsk;
struct glib_syms *glib;
struct gobject_syms *gobject;
struct gio_syms *gio;
struct gmodule_syms *gmodule;
struct girepository_syms *girepository;

static void print_hello(GtkWidget *widget, gpointer data) {
    glib->print("Hello\n");
}

static void activate(GtkApplication *app, gpointer _) {
    GtkWidget *window;
    GtkWidget *button;

    window = gtk->application_window_new(app);
    gtk->window_set_title((GtkWindow *)window, "Hello from cosmopolitan");
    gtk->window_set_default_size((GtkWindow *)window, 200, 200);

    button = gtk->button_new_with_label("Hello");
    gtk->widget_set_halign(button, GTK_ALIGN_CENTER);
    gtk->widget_set_valign(button, GTK_ALIGN_CENTER);

    gobject->signal_connect_data(
        button, "clicked", (GCallback)print_hello, NULL, NULL, G_CONNECT_DEFAULT
    );
    gobject->signal_connect_data(
        button, "clicked", G_CALLBACK(print_hello), window, NULL,
        G_CONNECT_SWAPPED
    );

    gtk->window_set_child((GtkWindow *)window, button);

    gtk->window_present((GtkWindow *)window);
}

int main(int argc, char **argv) {
    initialize_glib();
    initialize_gobject();
    initialize_gio();
    initialize_gmodule();
    initialize_gir();
    initialize_gtk4();

    GtkApplication *app;
    int status;

    app =
        gtk->application_new("cosmo.gtk.template", G_APPLICATION_DEFAULT_FLAGS);

    gobject->signal_connect_data(
        app, "activate", G_CALLBACK(activate), NULL, NULL, G_CONNECT_DEFAULT
    );

    status = gio->application_run((GApplication *)app, argc, argv);

    gobject->object_unref(app);

    close_glib();
    close_gobject();
    close_gio();
    close_gmodule();
    close_gir();
    close_gtk4();

    return status;
}
