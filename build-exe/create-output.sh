#!/bin/bash
#
# Script that creates the "output" directory starting from the directory created by
# "make install" calls
#
# Arguments:
# $1: the directory containing the files created by the "make install-strip" calls
# $2: the directory where the files should be copied to
# $3: the strip command
#

set -o errexit
set -o nounset
set -o pipefail

#
# Copy a file to the output directory
#
# Arguments:
#  $1: the full path to the source file
#  $2: special type (binary, text, doc). If omitted, no special handling will be performed
#  $3: the relative path of the destination file (if omitted we'll calculate it)
#
copyFile()
{
    local sourcePath="$1"
    local fileType="${2:-}"
    local relativePath="${3:-}"
    if [ -z "$relativePath" ]; then
        relativePath="${sourcePath#${SOURCE}/}"
    fi
    local destinationPath="$DESTINATION/$relativePath"
    if [ "$fileType" = doc ]; then
        local destinationPath2="${destinationPath%.1.html}"
        if [ "$destinationPath" != "$destinationPath2" ]; then
            destinationPath="$destinationPath2.html"
        fi
    fi
    mkdir -p "$(dirname "$destinationPath")"
    case "$fileType" in
        binary)
            printf 'Copying binary file %s... ' "$relativePath"
            local bytesPre=$(stat -c%s "$sourcePath")
            "$STRIP_COMMAND" --strip-unneeded "$sourcePath" -o "$destinationPath"
            local bytesPre=$(stat -c%s "$destinationPath")
            bytesSaved=$((bytesPre - bytesPre))
            if [ $bytesSaved -eq 0 ]; then
                printf 'done (no bytes saved out of %s)\n' $bytesPre
            else
                printf 'done (%s bytes saved out of %s)\n' $bytesSaved $bytesPre
            fi
            ;;
        text)
            printf 'Copying text file %s (converting line endings)... ' "$relativePath"
            local unix2dosOutput
            if ! unix2dosOutput="$(unix2dos -n "$sourcePath" "$destinationPath" 2>&1)"; then
                printf 'unix2dos failed!\n%s\n' "$unix2dosOutput"
                return 1
            fi
            printf 'done.\n'
            ;;
        *)
            printf 'Copying file %s... ' "$relativePath"
            cp "$sourcePath" "$destinationPath"
            printf 'done.\n'
            ;;
    esac
}

SOURCE="${1:-}"
SOURCE="${SOURCE%/}"
if [ -z "$SOURCE" ]; then
    echo 'Missing 1st argument (source directory)'
    exit 1
fi
if [ ! -d "$SOURCE" ]; then
    printf 'Source directory (%s) not found\n' "$SOURCE"
    exit 1
fi
DESTINATION="${2:-}"
DESTINATION="${DESTINATION%/}"
if [ -z "$SOURCE" ]; then
    echo 'Missing 2nd argument (destination directory)'
    exit 1
fi
if [ ! -d "$DESTINATION" ]; then
    printf 'Destination directory (%s) not found\n' "$DESTINATION"
    exit 1
fi
STRIP_COMMAND="${3:-}"
if [ -z "$STRIP_COMMAND" ]; then
    echo 'Missing 3rd argument (strip command)'
    exit 1
fi

mkdir -p "$DESTINATION/share/gettext"

for i in $(find "$SOURCE" -maxdepth 1 -type f -name license*.txt); do
    copyFile "$i" text
done
for i in $(find "$SOURCE/bin/" -name '*.exe' -o -name '*.dll'); do
    copyFile "$i" binary
done
if [ -f "$SOURCE/lib/charset.alias" ]; then
    copyFile "$SOURCE/lib/charset.alias"
fi
for i in $(find "$SOURCE/share/doc" -maxdepth 2 -type f ! -iname '*.3.html' ! -iname 'autopoint.1.html' ! -iname 'gettextize.1.html'); do
    copyFile "$i" doc
done
if [ "${BUILD_ONLY_ICONV:-}" != y ]; then
    copyFile "$SOURCE/lib/gettext/cldr-plurals.exe" binary bin/cldr-plurals.exe
    cp -r "$SOURCE/share/locale" "$DESTINATION/share/"
    cp -r "$SOURCE/share/gettext/styles" "$DESTINATION/share/gettext/"
    cp -r $SOURCE/share/gettext-*/its "$DESTINATION/share/gettext"
    copyFile "$SOURCE/share/gettext/msgunfmt.tcl"
    copyFile "$SOURCE/lib/gettext/common/supplemental/plurals.xml"
fi
