#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

COSMO_DIR="$1"

if [[ -z "$COSMO_DIR" ]]; then
    printf "Please pass your cosmopolitan directory (directory containing libc headers!) as the first argument to the script!\n"
    exit 1
fi

if ! [[ -d "$COSMO_DIR" ]]; then
    printf "Provided directory %s does not exist!\n" "$COSMO_DIR"
    exit 1
fi

if ! [[ -d "$COSMO_DIR/include" ]]; then
    printf "Provided directory %s does not contain subdirectory include\n" "$COSMO_DIR"
    exit 1
fi

if ! [[ -f "$COSMO_DIR/include/libc/integral/c.inc" ]]; then
    printf "Provided directory %s does not contain file include/libc/intergal/c.inc\n" "$COSMO_DIR"
    exit 1
fi

COMPILE_FLAGS_PATH="$SCRIPT_DIR/../compile_flags.txt"

stubs=""

for path in ./stubs/*; do
    if [ -d "$path" ]; then
        stubs="$stubs\n-isystem$path"
    fi
done

echo -e """
$stubs
-isystem/usr/include/gtk-4.0/
-isystem/usr/include/glib-2.0/
-isystem/usr/include/gtk-4.0/
-isystem/usr/include/cairo
-isystem/usr/include/pango-1.0
-isystem/usr/include/harfbuzz
-isystem/usr/include/gdk-pixbuf-2.0
-isystem/usr/include/graphene-1.0
-isystem/usr/lib/glib-2.0/include
-isystem/usr/lib/graphene-1.0/include
-isystem./headers
-DGTK_COMPILATION
-include$COSMO_DIR/include/libc/integral/c.inc
-isystem$COSMO_DIR/include/
""" | sed -e '/^$/d' >"$COMPILE_FLAGS_PATH"
