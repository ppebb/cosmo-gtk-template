return {
    -- From https://github.com/GNOME/glib/blob/83200855579964a20d3929f37a37431e4952d156/gobject/gobject.c#L2406
    g_object_new = [[gpointer g_object_new(GType object_type, const gchar *first_property_name, ...) {
    GObject *object;
    va_list var_args;

    /* short circuit for calls supplying no properties */
    if (!first_property_name)
        return stub_funcs.ptr_g_object_new_with_properties(object_type, 0, NULL, NULL);

    va_start(var_args, first_property_name);
    object = stub_funcs.ptr_g_object_new_valist(object_type, first_property_name, var_args);
    va_end(var_args);

    return object;
}]],
}
