#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

cd "$SCRIPT_DIR"

if ! [ -f "header_map.sh" ]; then
    printf "header_map.sh is not present! Did you delete it?\n"
    exit 1
fi

if ! [ -x "header_map.sh" ]; then
    chmod u+x header_map.sh
fi

source header_map.sh

for entry in "${map[@]}"; do
    IFS=";" read -r -a split_arr <<<"${entry}"

    source="${split_arr[0]}"
    dest="${split_arr[1]}"
    # Paths in the generated map are relative to where the lua script was
    # originally called from. They'll either contain scripts/ or if the script
    # was called from its own directory then they start with ./
    dest_p=${dest##*scripts/}

    printf "Copying source \"%s\" to dest \"%s\"\n" "$source" "$(realpath "$dest_p")"

    mkdir -p "$(dirname "$dest_p")"

    cp -r "$source" "$dest_p"
done
