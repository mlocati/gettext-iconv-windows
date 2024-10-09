#!/bin/bash
#
# Script that fetches the newest .po files from the translationproject.org website
#
# Arguments:
# $1: the directory containing the .po files
# $2: the path to the .pot file
# $3: the URL slug representing the package (libiconv, gettext-tools, gettext-runtime, gettext-examples)
# $4: the URL slug representing the version (1.17-pre1, 0.22) - if empty we'll use "latest"
#

set -o errexit
set -o nounset
set -o pipefail

poDir="${1:-}"
if [ -z "$poDir" ]; then
    echo 'Missing the directory containing the .po files'
    exit 1
fi
if [ ! -d "$poDir" ]; then
    printf 'The directory containing the .po files (%s) does not exist\n' "$poDir"
    exit 1
fi

potFile="${2:-}"
if [ -z "$potFile" ]; then
    echo 'Missing the path of the .pot file'
    exit 1
fi
if [ ! -f "$potFile" ]; then
    printf 'The .pot file (%s) does not exist\n' "$potFile"
    exit 1
fi

poTPPackage="${3:-}"
if [ -z "$poTPPackage" ]; then
    echo 'Missing the URL slug of the package handle'
    exit 1
fi

poTPVersion="${4:-}"
if [ -z "$poTPVersion" ]; then
    poTPVersion=latest
fi

poUrl="https://translationproject.org/latest/$poTPPackage/"

printf 'Downloading %s translations from %s\n' "$poTPVersion" "$poUrl"
tmpDir="$(mktemp -d)"
wget --recursive --level=1 --no-directories --accept=.po --directory-prefix="$tmpDir" --no-verbose -- "$poUrl"
for newPOFile in $(find "$tmpDir" -type f -name '*.po'); do
    poLang="${newPOFile##*/}"
    poLang="${poLang%.po}"
    if [ "$poTPVersion" != latest ]; then
        wget --no-verbose --output-document="$newPOFile" "https://translationproject.org/PO-files/$poLang/$poTPPackage-$poTPVersion.$poLang.po"
    fi
    printf 'Processing %s... ' "$poLang"
    msgmerge --output-file="$poDir/$poLang.po" --no-fuzzy-matching --lang="$poLang" -- "$newPOFile" "$potFile" 2>&1
done
rm -rf -- "$tmpDir"
