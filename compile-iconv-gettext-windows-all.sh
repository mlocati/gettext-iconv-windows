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

function doCompile {
    rm -rf "${SCRIPT_PATH}/compiled/$1-$2" || rm -rf "${SCRIPT_PATH}/compiled/$1-$2" || rm -rf "${SCRIPT_PATH}/compiled/$1-$2"
    "${SCRIPT_PATH}/compile-iconv-gettext-windows.sh" --link $1 --bits $2 --iconv - --gettext - --output "${SCRIPT_PATH}/compiled/$1-$2" --quiet
}

doCompile shared 32
doCompile shared 64
doCompile static 32
doCompile static 64
