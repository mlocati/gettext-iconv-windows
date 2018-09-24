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

"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 32 --link static --iconv 1.15 --gettext 0.19.8.1
"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 32 --link shared --iconv 1.15 --gettext 0.19.8.1
"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 64 --link static --iconv 1.15 --gettext 0.19.8.1
"${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --bits 64 --link shared --iconv 1.15 --gettext 0.19.8.1
