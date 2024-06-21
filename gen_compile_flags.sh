#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

COSMO_DIR="$1"

printf "Warning: Not all required flags are present! Many glib and related libraries are just not there so this only works for cosmopolitan"

if [[ -z "$COSMO_DIR" ]]; then
    printf "Please pass your cosmopolitan directory (directory containing libc headers!) as the first argument to the script!\n"
    exit 1
fi

COMPILE_FLAGS_PATH="$SCRIPT_DIR/nightglow/compile_flags.txt"

echo -e """
-include$COSMO_DIR/libc/integral/c.inc
-isystem$COSMO_DIR
""" >"$COMPILE_FLAGS_PATH"
