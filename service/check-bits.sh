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
    local expectedBits
    case "$(basename "$checkMe")" in
        GNU.Gettext.dll | msgfmt.net.exe | msgunfmt.net.exe | csharpexec-test.exe)
            expectedBits=32
            ;;
        *)
            expectedBits=$BITS
            ;;
    esac
    printf 'Checking %s... ' "$checkMe"
    local info="$(file -bEh -- "$checkMe" | head -n1)"
    local detectedBits
    case "$info" in
        *PE32+*)
            detectedBits=64
            ;;
        *PE32*)
            detectedBits=32
            ;;
        *)
            printf 'NOT A WINDOWS PE: %s\n' "$info"
            return 1
            ;;
    esac
    local detectedKind
    case "$info" in
        *DLL*)
            detectedKind=dll
            ;;
        *)
            detectedKind=exe
            ;;
    esac
    local detectedType
    case "$info" in
        *console*)
            detectedType=console
            ;;
        *GUI*)
            detectedType=GUI
            ;;
        *)
            detectedType=unknown
            ;;
    esac
    printf '%s-bit %s (%s): ' "$detectedBits" "$detectedKind" "$detectedType"
    if [ $detectedBits -ne $expectedBits ]; then
        echo 'INVALID'
        return 1
    fi
    echo 'OK'
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
