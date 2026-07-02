#!/bin/bash
#
# Script that builds a sorted list of assets
#
# Arguments:
# $1: Path to the directory containing the assets

set -o errexit
set -o nounset
set -o pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
    echo 'Please provide the path to the directory containing the assets as the first and only argument.'
    exit 1
fi
dir="$1"
if [ ! -d "$dir" ]; then
    printf "The provided path '%s' is not a directory.\n" "$dir"
    exit 1
fi

find "$dir" -type f -print0 | while IFS= read -r -d '' f; do
    case "$f" in
        *shared-32.exe)
            p=01
            ;;
        *shared-32.zip)
            p=02
            ;;
        *shared-64.exe)
            p=03
            ;;
        *shared-64.zip)
            p=04
            ;;
        *shared-arm64.exe)
            p=05
            ;;
        *shared-arm64.zip)
            p=06
            ;;
        *static-32.exe)
            p=07
            ;;
        *static-32.zip)
            p=08
            ;;
        *static-64.exe)
            p=09
            ;;
        *static-64.zip)
            p=10
            ;;
        *static-arm64.exe)
            p=11
            ;;
        *static-arm64.zip)
            p=12
            ;;
        *shared-32-dev-gcc.zip)
            p=13
            ;;
        *shared-32-dev-msvc.zip)
            p=14
            ;;
        *shared-64-dev-gcc.zip)
            p=15
            ;;
        *shared-64-dev-msvc.zip)
            p=16
            ;;
        *shared-arm64-dev-gcc.zip)
            p=17
            ;;
        *shared-arm64-dev-msvc.zip)
            p=18
            ;;
        *static-32-dev-gcc.zip)
            p=19
            ;;
        *static-32-dev-msvc.zip)
            p=20
            ;;
        *static-64-dev-gcc.zip)
            p=21
            ;;
        *static-64-dev-msvc.zip)
            p=22
            ;;
        *static-arm64-dev-gcc.zip)
            p=23
            ;;
        *static-arm64-dev-msvc.zip)
            p=24
            ;;
        *)
            p=99
            ;;
    esac
    printf "%s\t%s\n" "$p" "$(realpath -- "$f")"
done | sort -k1,1n -k2 | cut -f2
