#!/usr/bin/env bash

SOURCE="$1"
DEST="$2"

set -e

if ! [ -f "$SOURCE" ]; then
    printf "Source (arg 1) is not a file or inaccessible: %s" "$SOURCE"
    exit 1
fi

if [ -z "$DEST" ]; then
    printf "Destination (arg 2) is missing: %s" "$DEST"
    exit 1
fi

if [ -p "/dev/stdin" ]; then
    ppout=$(cat)
else
    printf "No input provided over stdin"
    exit 1
fi

dest_dir=$(dirname "$DEST")
mkdir -p "$dest_dir"

if [[ "$SOURCE" = *"/stubs/"* ]]; then
    cp "$SOURCE" "$DEST"
    exit
fi

includes=$(grep "#include" "$SOURCE")

escaped=${SOURCE#./}
escaped=$(sed "s;\/;\\\/;g" <<<"$escaped" | sed "s;\.;\\\.;g")
pp_post_include=$(tac <<<"$ppout" | sed -e "/\"$escaped\" 2/q" | tac | sed "s/\([^A-Za-z_-]\)g_/\1glib->g_/g" | sed "s/\([^A-Za-z_-]\)gtk_/\1gtk->gtk_/g" | sed "s/\([^A-Za-z_-]\)gsk_/\1gtk->gsk_/g" | sed "s/\([^A-Za-z_-]\)gdk_/\1gtk->gdk_/g")

echo "$includes
$pp_post_include" >"$DEST"
