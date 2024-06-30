local lfs = require("lfs")
local stub = require("scripts.stub")
local utils = require("scripts.utils")

local script_path = utils.get_script_dir()

if not script_path then
    utils.fprintf(io.stderr, "Unable to determine script path, exiting...\n")
    os.exit(1, true)
end

local stubs_root = utils.path_combine(script_path, "..", "stubs/")
local extra_headers_dir = utils.path_combine(stubs_root, "headers")

if not utils.file_exists(stubs_root) then
    assert(lfs.mkdir(stubs_root))
end

if not utils.file_exists(extra_headers_dir) then
    assert(lfs.mkdir(extra_headers_dir))
end

local _ = stub.new(stubs_root, "gtk4")
    :with_shared_object("gtk", { "libgtk-4.so" })
    :with_lib_headers({
        "gtk/gtk.h",
        "gtk/a11y/gtkatspi.h",
        "gdk/x11/gdkx.h",
        "gdk/wayland/gdkwayland.h",
        "gdk/broadway/gdkbroadway.h",
    })
    :with_extra_headers({
        "/usr/include/wayland-client-core.h",
        "/usr/include/wayland-client-protocol.h",
        "/usr/include/wayland-client.h",
        "/usr/include/wayland-cursor.h",
        "/usr/include/wayland-egl-backend.h",
        "/usr/include/wayland-egl-core.h",
        "/usr/include/wayland-egl.h",
        "/usr/include/wayland-server-core.h",
        "/usr/include/wayland-server-protocol.h",
        "/usr/include/wayland-server.h",
        "/usr/include/wayland-util.h",
        "/usr/include/wayland-version.h",
        "/usr/include/X11",
    }, extra_headers_dir)
    :set_trim_prefix(false)
    :set_match_access({ "GDK_[A-Z0-9_]+" })
    :set_prefix("gtk_")
    :process_headers({ "/usr/include/gtk-4.0/gtk/" })
    :set_prefix("gdk_")
    :process_headers({ "/usr/include/gtk-4.0/gdk/" })
    :set_prefix("gsk_")
    :process_headers({ "/usr/include/gtk-4.0/gsk/" })
    :write()

local _ = stub.new(stubs_root, "glib")
    :with_shared_object("glib", { "libglib-2.0.so" })
    :with_shared_object("gobject", { "libgobject-2.0.so" })
    :with_shared_object("gio", { "libgio-2.0.so" })
    :with_shared_object("gmodule", { "libgmodule-2.0.so" })
    :with_shared_object("girepository", { "libgirepository-2.0.so" })
    :with_lib_headers({
        "glib.h",
        "glib-unix.h",
        "glib-object.h",
        "gio/gio.h",
        "gmodule.h",
        "girepository/girepository.h",
        "girepository/girffi.h",
    })
    :with_extra_headers({
        "/usr/include/ffi.h",
        "/usr/include/ffitarget.h",
    }, extra_headers_dir)
    :set_prefix("g_")
    :set_trim_prefix(false)
    :use_shared_object("glib")
    :set_match_access({
        "GLIB_[A-Z0-9_]+",
        "G_NORETURN",
    })
    :set_skip_funcs({
        "g_win32_get_system_data_dirs_for_module",
        "g_signal_new ",
        "g_chmod",
        "g_open",
        "g_creat",
        "g_rename",
        "g_mkdir",
        "g_stat",
        "g_lstat",
        "g_remove",
        "g_fopen",
        "g_freopen",
        "g_fsync",
        "g_utime",
        "alloca",
    })
    :process_headers({
        "/usr/include/glib-2.0/glib/",
        "/usr/include/glib-2.0/glib-unix.h",
    })
    :use_shared_object("gobject")
    :set_skip_files({ "%.c$" })
    :set_match_access({ "GOBJECT_[A-Z0-9_]+" })
    :process_headers({ "/usr/include/glib-2.0/gobject/" })
    :use_shared_object("gio")
    :set_skip_files(nil)
    :set_match_access({
        "GIO_[A-Z0-9_]+",
        "G_MODULE_EXPORT[A-Z0-9_]*",
        "GMODULE_[A-Z0-9_]+",
    })
    :process_headers({ "/usr/include/glib-2.0/gio/" })
    :use_shared_object("gmodule")
    :set_match_access({
        "G_MODULE_EXPORT[A-Z0-9_]*",
        "GMODULE_[A-Z0-9_]+",
    })
    :process_headers({
        "/usr/include/glib-2.0/gmodule/",
        "/usr/include/glib-2.0/gmodule.h",
    })
    :use_shared_object("girepository")
    :set_match_access({ "GI_[A-Z0-9_]+" })
    :set_prefix("gi_")
    :process_headers({
        "/usr/include/glib-2.0/girepository/girepository.h",
        "/usr/include/glib-2.0/girepository/girffi.h",
    })
    :write()

print("Writing header_map.sh")
utils.file_write(
    utils.path_combine(script_path, "header_map.sh"),
    ('export map=(\n    "' .. utils.tbl_join(stub.copied_headers, '"\n    "') .. '"\n)')
)
