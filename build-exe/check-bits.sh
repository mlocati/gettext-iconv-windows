#!/bin/bash
#
# Script that checks if the binary files in a directory (and its sub-directoroes)
# have the correct bitness
#
# Arguments:
# $1: the number of bits (32, 64)
# $2: the directory to be checked, or the path to a file
#

set -o errexit
set -o nounset
set -o pipefail

BITS="${1:-}"
case "$BITS" in
    32 | 64) ;;
    '')
        echo 'Missing bitness'
        exit 1
        ;;
    *)
        printf 'Invalid bitness: %s\n' "$BITS"
        exit 1
        ;;
esac

CHECK_ME="${2:-}"
if [ -z "$CHECK_ME" ]; then
    echo 'Missing file/directory to be checked'
    exit 1
fi

# Arguments:
# $1: the file
checkBits()
{
    local checkMe="$1"
    local actualBits
    case "$(basename "$checkMe")" in
        GNU.Gettext.dll | msgfmt.net.exe | msgunfmt.net.exe)
            actualBits=32
            ;;
        *)
            actualBits=$BITS
            ;;
    esac
    printf 'Checking %s... ' "$checkMe"
    local info="$(file -bEh -- "$checkMe" | head -n1)"
    case "$info" in
        PE32\ executable\ \(console\)\ Intel\ 80386*)
            printf '32-bit exe (console): '
            if [ $actualBits -ne 32 ]; then
                echo 'INVALID'
                return 1
            fi
            echo 'OK'
            ;;
        PE32\ executable\ \(GUI\)\ Intel\ 80386*)
            printf '32-bit exe (GUI): '
            if [ $actualBits -ne 32 ]; then
                echo 'INVALID'
                return 1
            fi
            echo 'OK'
            ;;
        PE32\ executable\ \(DLL\)\ \(console\)\ Intel\ 80386*)
            printf '32-bit dll: '
            if [ $actualBits -ne 32 ]; then
                echo 'INVALID'
                return 1
            fi
            echo 'OK'
            ;;
        PE32+\ executable\ \(console\)\ x86-64*)
            printf '64-bit exe (console): '
            if [ $actualBits -ne 64 ]; then
                echo 'INVALID'
                return 1
            fi
            echo 'OK'
            ;;
        PE32+\ executable\ \(GUI\)\ x86-64*)
            printf '64-bit exe (GUI): '
            if [ $actualBits -ne 64 ]; then
                echo 'INVALID'
                return 1
            fi
            echo 'OK'
            ;;
        PE32+\ executable\ \(DLL\)\ \(console\)\ x86-64*)
            printf '64-bit dll: '
            if [ $actualBits -ne 64 ]; then
                echo 'INVALID'
                return 1
            fi
            echo 'OK'
            ;;
        *)
            printf 'UNRECOGNISED INFO: %s\n' "$info"
            return 1
            ;;
    esac
}

if [ -d "$CHECK_ME" ]; then
    allOk=1
    for f in $(find "$CHECK_ME" -type f -name *.dll -o -name *.exe); do
        if ! checkBits "$f"; then
            allOk=0
        fi
    done
    if [ $allOk -ne 1 ]; then
        echo 'FAILURE!'
        exit 1
    fi
elif [ -f "$CHECK_ME" ]; then
    if ! checkBits "$CHECK_ME"; then
        echo 'FAILURE!'
        exit 1
    fi
else
    printf 'Unable to find the file or directory %s\n' "$CHECK_ME"
    exit 1
fi
