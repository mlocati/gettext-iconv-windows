#!/bin/bash
#
# Script that creates the "output" directory starting from the directory created by
# "make install" calls
#
# Arguments:
# $1: the directory created by the "make install calls
# $2: the directory where the files should be copied to
# $3: the MinGW-w64 host (i686-w64-mingw32, x86_64-w64-mingw32)
#

set -o errexit
set -o nounset
set -o pipefail

#
# Copy a file to the output directory
#
# Arguments:
#  $1: the full path to the source file
#  $2: special type (binary, text, doc). If omitted, no special operation will be performed
#  $3: the relative path of the destination file (if omitted we'll calculate it)
#
copyFile () {
    local sourcePath="$1"
    local fileType="${2:-}"
    local relativePath="${3:-}"
    if [ -z "$relativePath" ]; then
        relativePath="${sourcePath#${SOURCE}/}"
    fi
    local destinationPath="$DESTINATION/$relativePath"
    if [ "$fileType" = doc ]; then
        local destinationPath2
        destinationPath2="${destinationPath%.1.html}"
        if test "$destinationPath" != "$destinationPath2"; then
            destinationPath="$destinationPath2.html"
        fi
    fi
    mkdir -p "$(dirname "$destinationPath")"
    case "$fileType" in
        binary)
            "$MINGW_HOST-strip" --strip-unneeded "$sourcePath" -o "$destinationPath"
            ;;
        text)
            perl -pe 's/\r\n|\n|\r/\r\n/g' <"$sourcePath" >"$destinationPath"
            ;;
        * )
            cp "$sourcePath" "$destinationPath"
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
MINGW_HOST="${3:-}"
if [ -z "$MINGW_HOST" ]; then
    echo 'Missing 3nd argument (MinGW-w64 host)'
    exit 1
fi

mkdir -p "$DESTINATION/share/gettext"

# copyFile "$SOURCE/cldr-license.txt" text @todo uncomment
copyFile "$SOURCE/iconv-license.txt" text @todo uncomment
# copyFile "$SOURCE/gettext-license.txt" text @todo uncomment
for i in $(find "$SOURCE/bin/" -name '*.exe' -o -name '*.dll'); do
    copyFile "$i" binary
done
# copyFile "$SOURCE/lib/gettext/cldr-plurals.exe" binary bin/cldr-plurals.exe @todo uncomment
if [ -f "$SOURCE/lib/charset.alias" ]; then
    copyFile "$SOURCE/lib/charset.alias"
fi
for i in $(find "$SOURCE/share/doc" -maxdepth 2 -type f ! -iname '*.3.html' ! -iname 'autopoint.1.html' ! -iname 'gettextize.1.html'); do
    copyFile "$i" doc
done
# cp -r "$SOURCE/share/locale" "$DESTINATION/share/" @todo uncomment
# cp -r "$SOURCE/share/gettext/styles" "$DESTINATION/share/gettext/" @todo uncomment
# cp -r $SOURCE/share/gettext-*/its "$DESTINATION/share/gettext" @todo uncomment
# copyFile "$SOURCE/share/gettext/msgunfmt.tcl" @todo uncomment
# copyFile "$SOURCE/cldr-plurals.xml" '' lib/gettext/common/supplemental/plurals.xml @todo uncomment
