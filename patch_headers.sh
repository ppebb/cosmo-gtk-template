#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

cd "$SCRIPT_DIR"

for arg in "${@}"; do
    if ! [ -d "$arg" ]; then
        printf "Argument %s does not exist or is not a directory!\n" "$arg"
        continue
    fi

    cd "$arg"

    find . -name "*.h" -print0 | while read -d $'\0' header; do
        printf "Patching header %s\n" "$(realpath "$header")"

        # Turn angle bracket includes to double quote includes
        sed -i 's/#include <\([-A-Za-z0-9\/\.]*\)>/#include "\1"/' "$header"

        sed -i 's/pthread\.h/libc\/thread\/thread\.h/' "$header"

    done

    cd "$SCRIPT_DIR"
done
