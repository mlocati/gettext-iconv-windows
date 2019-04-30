#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

pushd . > /dev/null
SCRIPT_PATH="${BASH_SOURCE[0]}";
while([ -h "${SCRIPT_PATH}" ]) do
    cd "`dirname "${SCRIPT_PATH}"`"
    SCRIPT_PATH="$(readlink "`basename "${SCRIPT_PATH}"`")";
done
cd "`dirname "${SCRIPT_PATH}"`" > /dev/null
SCRIPT_PATH="`pwd`";
popd > /dev/null

BLDGTXT_ALL_ICONV_V=1.16
BLDGTXT_ALL_GETTEXT_V=0.20-rc1

rm -rf "${SCRIPT_PATH}/compiled/static-32"
rm -rf "${SCRIPT_PATH}/compiled/shared-32"
rm -rf "${SCRIPT_PATH}/compiled/static-64"
rm -rf "${SCRIPT_PATH}/compiled/shared-64"

mkdir "${SCRIPT_PATH}/compiled/static-32"
mkdir "${SCRIPT_PATH}/compiled/shared-32"
mkdir "${SCRIPT_PATH}/compiled/static-64"
mkdir "${SCRIPT_PATH}/compiled/shared-64"

"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 32 --link static --iconv "$BLDGTXT_ALL_ICONV_V" --gettext "$BLDGTXT_ALL_GETTEXT_V" --output "${SCRIPT_PATH}/compiled/static-32"
"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 32 --link shared --iconv "$BLDGTXT_ALL_ICONV_V" --gettext "$BLDGTXT_ALL_GETTEXT_V" --output "${SCRIPT_PATH}/compiled/shared-32"
"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 64 --link static --iconv "$BLDGTXT_ALL_ICONV_V" --gettext "$BLDGTXT_ALL_GETTEXT_V" --output "${SCRIPT_PATH}/compiled/static-64"
"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 64 --link shared --iconv "$BLDGTXT_ALL_ICONV_V" --gettext "$BLDGTXT_ALL_GETTEXT_V" --output "${SCRIPT_PATH}/compiled/shared-64"
