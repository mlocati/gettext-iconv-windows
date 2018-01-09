#!/bin/bash

#
# Script tested on a clean install of Ubuntu Server 16.04
#

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

unset `env | grep -vi '^EDITOR=\|^HOME=\|^LANG=\|MXE\|^PATH=' | grep -vi 'PKG_CONFIG\|PROXY\|^PS1=\|^TERM=' | cut -d '=' -f1 | tr '\n' ' '`

BLDGTXT_MXE=$HOME/mxe
if [ ! -d $BLDGTXT_MXE/usr/bin ]; then
    echo '### Installing required libraries'
    sudo apt-get update
    sudo apt-get install -y \
        autoconf automake autopoint bash bison bzip2 flex gettext git g++ \
        gperf intltool libffi-dev libgdk-pixbuf2.0-dev libtool libltdl-dev \
        libssl-dev libxml-parser-perl make openssl p7zip-full patch perl \
        pkg-config python ruby scons sed unzip wget xz-utils g++-multilib \
        libc6-dev-i386 perl groff
    set +o errexit
    sudo apt-get install -y libtool-bin
    set -o errexit
    rm -rf $BLDGTXT_MXE
    echo '### Downloading MXE'
    git clone https://github.com/mxe/mxe.git $BLDGTXT_MXE
    echo '### Building MXE (IT WILL TAKE UP TO ONE HOUR)'
    pushd $BLDGTXT_MXE >/dev/null
    make \
        MXE_TARGETS='i686-w64-mingw32.static i686-w64-mingw32.shared x86_64-w64-mingw32.static x86_64-w64-mingw32.shared' \
        gcc
    popd >/dev/null
fi

echo '### Setting environment'
export PATH=$BLDGTXT_MXE/usr/bin:$PATH
function bldgtxtGetSourceFolder {
    pushd . >/dev/null
    local DIR="${BASH_SOURCE[0]}";
    while([ -h "${DIR}" ]) do
        cd "`dirname "${DIR}"`"
        DIR="$(readlink "`basename "${DIR}"`")";
    done
    cd "`dirname "${DIR}"`" >/dev/null
    pwd
    popd >/dev/null
}
function bldgtxtReadCommandLine {
    local KEY
    while [ ! -z ${1+x} ]; do
        KEY="$1"
        shift
        case $KEY in
            -i|--iconv)
                BLDGTXT_V_ICONV=$1
                shift
                ;;
            -g|--gettext)
                BLDGTXT_V_GETTEXT=$1
                shift
                ;;
            -b|--bits)
                BLDGTXT_BITS=$1
                shift
                ;;
            -l|--link)
                BLDGTXT_LINK=$1
                shift
                ;;
            -o|--output)
                BLDGTXT_OUTPUT_CUSTOM=$1
                shift
                ;;
            -q|--quiet)
                BLDGTXT_QUIET=1
                ;;
            -h|--help)
                echo "Usage: $0 [-i|--iconv <iconv version|default>] [-g|--gettext <gettext version|default>] [-b|--bits <32|64>] [-l|--link <shared|static>] [-o|--output <dir>] [-q|--quiet]"
                echo "Default iconv version: $BLDGTXT_V_ICONV_DEFAULT"
                echo "Default gettext version: $BLDGTXT_V_GETTEXT_DEFAULT"
                echo "Default bits: $BLDGTXT_BITS_DEFAULT"
                echo "Default link: $BLDGTXT_LINK_DEFAULT"
                exit 0
                ;;
            *)
                echo "Unknown option: $KEY" >&2
                echo "Type $0 -h for help" >&2
                exit 1
                ;;
        esac
    done
}
function bldgtxtAskVersion {
    local ANSWER
    read -p "$1 version [$2]: " ANSWER
    echo ${ANSWER:-$2}
}
function bldgtxtAskBits {
    local ANSWER
    read -p "Architecture (32 for 32bit, 64 for 64bit) [$BLDGTXT_BITS_DEFAULT]: " ANSWER
    echo ${ANSWER:-$BLDGTXT_BITS_DEFAULT}
}
function bldgtxtAskLink {
    local ANSWER
    read -p "Link (shared for smaller but with DLL, static for no DLL but bigger results) [$BLDGTXT_LINK_DEFAULT]: " ANSWER
    echo ${ANSWER:-$BLDGTXT_LINK_DEFAULT}
}
function bldgtxtDownload {
    if [ ! -f $BLDGTXT_ARCHIVES/$2 ]; then
        echo "Downloading $2"
        set +o errexit
        wget --quiet --tries=3 --output-document=$BLDGTXT_ARCHIVES/$2 -- $1 || {
            echo "Failed to download $1" >&2
            rm $BLDGTXT_ARCHIVES/$2 >/dev/null 2>&1
            exit 1
        }
        set -o errexit
    fi
}
function bldgtxtApplyPatches {
    local PATCH_DIR=$1
    if [ -d "$PATCH_DIR" ]; then
        local PATCH_BEFORE="$PATCH_DIR/before.sh"
        if [ -f "$PATCH_BEFORE" ]; then
            echo " - before-patch step"
            bash "$PATCH_BEFORE"
        fi
        local PATCHES_PATTERN="$PATCH_DIR/*.patch"
        local PATCH_FILE
        for PATCH_FILE in $PATCHES_PATTERN; do
            echo " - patching ($(basename "$PATCH_FILE"))"
            patch --strip=1 --input="$PATCH_FILE" --silent
        done
        local PATCH_AFTER="$PATCH_DIR/after.sh"
        if [ -f "$PATCH_AFTER" ]; then
            echo " - after-patch step"
            bash "$PATCH_AFTER"
        fi
    fi
}
function copyBinary {
    ${BLDGTXT_BINUTILSPREFIX}strip --strip-unneeded "$1" -o $BLDGTXT_OUTPUT/bin/`basename $1`
}
echo '### Reading configuration'
BLDGTXT_OUTPUT_CUSTOM=
BLDGTXT_V_ICONV_DEFAULT=1.14
BLDGTXT_V_ICONV=
BLDGTXT_V_GETTEXT_DEFAULT=0.19.8.1
BLDGTXT_V_GETTEXT=
BLDGTXT_BITS_DEFAULT=32
BLDGTXT_BITS=
BLDGTXT_LINK_DEFAULT=static
BLDGTXT_LINK=
BLDGTXT_QUIET=0
BLDGTXT_MAKE_JOBS=
bldgtxtReadCommandLine "$@"
if [ -z "$BLDGTXT_V_ICONV" ]; then
    BLDGTXT_V_ICONV=$(bldgtxtAskVersion iconv $BLDGTXT_V_ICONV_DEFAULT)
else
    if [ "$BLDGTXT_V_ICONV" = 'default' ]; then
        BLDGTXT_V_ICONV=$BLDGTXT_V_ICONV_DEFAULT
    fi
    echo "iconv version: $BLDGTXT_V_ICONV"
fi
if [ -z "$BLDGTXT_V_GETTEXT" ]; then
    BLDGTXT_V_GETTEXT=$(bldgtxtAskVersion gettext $BLDGTXT_V_GETTEXT_DEFAULT)
else
    if [ "$BLDGTXT_V_GETTEXT" = 'default' ]; then
        BLDGTXT_V_GETTEXT=$BLDGTXT_V_GETTEXT_DEFAULT
    fi
    echo "gettext version: $BLDGTXT_V_GETTEXT"
fi
if [ -z "$BLDGTXT_BITS" ]; then
    BLDGTXT_BITS=$(bldgtxtAskBits)
else
    echo "No. of bits: $BLDGTXT_BITS"
fi
if [ -z "$BLDGTXT_LINK" ]; then
    BLDGTXT_LINK=$(bldgtxtAskLink)
else
    echo "Link: $BLDGTXT_LINK"
fi
case $BLDGTXT_BITS in
    32)
        BLDGTXT_BITS2=i686
        ;;
    64)
        BLDGTXT_BITS2=x86_64
        ;;
    *)
        echo "Unsupported number of bits: $BLDGTXT_BITS" >&2
        exit 1
        ;;
esac
case $BLDGTXT_LINK in
    shared)
        BLDGTXT_LINK_EXPANDED=' --enable-shared --disable-static '
        BLDGTXT_CPPFLAGS=
        ;;
    static)
        BLDGTXT_LINK_EXPANDED=' --disable-shared --enable-static '
        BLDGTXT_CPPFLAGS=' -DLIBXML_STATIC'
        ;;
    *)
        echo "Unsupported link: $BLDGTXT_LINK" >&2
        exit 1
        ;;
esac
BLDGTXT_QUIET_CONFIGURE=
BLDGTXT_QUIET_CPPFLAGS=
BLDGTXT_QUIET_MAKE=
if [[ $BLDGTXT_QUIET == 1 ]]; then
    BLDGTXT_QUIET_CONFIGURE='--quiet --enable-silent-rules'
    BLDGTXT_QUIET_CPPFLAGS='-Wno-pointer-to-int-cast -Wno-int-to-pointer-cast -Wno-attributes -Wno-write-strings'
    BLDGTXT_QUIET_MAKE='-silent LIBTOOLFLAGS=--silent'
else
    BLDGTXT_MAKE_JOBS='--jobs=1'
fi

BLDGTXT_SCRIPTDIR=`bldgtxtGetSourceFolder`
BLDGTXT_ROOT=$HOME/build-gettext-windows
BLDGTXT_ARCHIVES=$BLDGTXT_ROOT/archives
BLDGTXT_PATCHES=$BLDGTXT_SCRIPTDIR/patches
BLDGTXT_BASEDIR=$BLDGTXT_ROOT/$BLDGTXT_LINK-$BLDGTXT_BITS
BLDGTXT_SOURCE=$BLDGTXT_BASEDIR/source
BLDGTXT_CONFIGURED=$BLDGTXT_BASEDIR/configured
BLDGTXT_COMPILED=$BLDGTXT_BASEDIR/compiled
BLDGTXT_OUTPUT_DEFAULT=$BLDGTXT_BASEDIR/output
BLDGTXT_RELOCPREFIXES='--enable-relocatable --prefix=/gettext'
BLDGTXT_PKG_CONFIG_PATH_NAME="PKG_CONFIG_PATH_${BLDGTXT_BITS2}_w64_mingw32_${BLDGTXT_LINK}"
BLDGTXT_BINUTILSPREFIX=$BLDGTXT_BITS2-w64-mingw32.$BLDGTXT_LINK-

export MXE_TARGETS="${BLDGTXT_BITS2}-w64-mingw32.${BLDGTXT_LINK}"
export PKG_CONFIG_PATH=$BLDGTXT_COMPILED
export $BLDGTXT_PKG_CONFIG_PATH_NAME=$PKG_CONFIG_PATH
unset BLDGTXT_PKG_CONFIG_PATH_NAME

echo '### Checking source archives'
mkdir --parents $BLDGTXT_ARCHIVES
bldgtxtDownload http://ftp.gnu.org/pub/gnu/libiconv/libiconv-$BLDGTXT_V_ICONV.tar.gz libiconv-$BLDGTXT_V_ICONV.tar.gz
bldgtxtDownload http://ftp.gnu.org/pub/gnu/gettext/gettext-$BLDGTXT_V_GETTEXT.tar.gz gettext-$BLDGTXT_V_GETTEXT.tar.gz
bldgtxtDownload http://unicode.org/Public/cldr/latest/core.zip cldr.zip

echo '### Resetting environment'
rm --recursive --force $BLDGTXT_SOURCE
rm --recursive --force $BLDGTXT_CONFIGURED
rm --recursive --force $BLDGTXT_COMPILED
rm --recursive --force $BLDGTXT_OUTPUT_DEFAULT
mkdir --parents $BLDGTXT_SOURCE
mkdir --parents $BLDGTXT_CONFIGURED
mkdir --parents $BLDGTXT_COMPILED
if [ -z "$BLDGTXT_OUTPUT_CUSTOM" ]; then
    BLDGTXT_OUTPUT=$BLDGTXT_OUTPUT_DEFAULT
    mkdir --parents $BLDGTXT_OUTPUT
else
    if [ -d "$BLDGTXT_OUTPUT_CUSTOM" ]; then
        if [ "$(ls -A $BLDGTXT_OUTPUT_CUSTOM)" ]; then
            echo "Output directory not empty: $BLDGTXT_OUTPUT_CUSTOM" >&2
            exit 1
        fi
    else
        mkdir --parents "$BLDGTXT_OUTPUT_CUSTOM"
    fi
    BLDGTXT_OUTPUT=`realpath --no-symlinks $BLDGTXT_OUTPUT_CUSTOM`
fi

echo '### Setting up iconv'
cd $BLDGTXT_SOURCE
tar --extract --gzip --file=$BLDGTXT_ARCHIVES/libiconv-$BLDGTXT_V_ICONV.tar.gz
cd libiconv-$BLDGTXT_V_ICONV
bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-configure"
mkdir $BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV
cd $BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV
echo '### Configuring iconv'
$BLDGTXT_SOURCE/libiconv-$BLDGTXT_V_ICONV/configure \
    --host=$MXE_TARGETS \
    $BLDGTXT_LINK_EXPANDED \
    $BLDGTXT_RELOCPREFIXES \
    $BLDGTXT_QUIET_CONFIGURE \
    --config-cache \
    --disable-dependency-tracking \
    --disable-nls \
    --disable-rpath \
    CPPFLAGS="$BLDGTXT_QUIET_CPPFLAGS"
bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-make"
echo '### Making iconv'
make $BLDGTXT_MAKE_JOBS --no-keep-going $BLDGTXT_QUIET_MAKE
echo '### Installing iconv'
make $BLDGTXT_MAKE_JOBS --no-keep-going $BLDGTXT_QUIET_MAKE DESTDIR=$BLDGTXT_COMPILED install

echo '### Setting up gettext'
cd $BLDGTXT_SOURCE
tar --extract --gzip --file=$BLDGTXT_ARCHIVES/gettext-$BLDGTXT_V_GETTEXT.tar.gz
cd gettext-$BLDGTXT_V_GETTEXT
bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-configure"
mkdir $BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT
cd $BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT
echo '### Configuring gettext'
$BLDGTXT_SOURCE/gettext-$BLDGTXT_V_GETTEXT/configure \
    --host=$MXE_TARGETS \
    $BLDGTXT_LINK_EXPANDED \
    $BLDGTXT_RELOCPREFIXES \
    $BLDGTXT_QUIET_CONFIGURE \
    --config-cache \
    --disable-dependency-tracking \
    --disable-java \
    --disable-native-java \
    --disable-csharp \
    --disable-rpath \
    --disable-openmp \
    --disable-curses \
    --without-emacs \
    --disable-acl \
    --enable-threads=windows \
    --with-included-libxml \
    --without-bzip2 \
    --without-xz \
    --with-included-libxml \
    CPPFLAGS="-I$BLDGTXT_COMPILED/gettext/include $BLDGTXT_QUIET_CPPFLAGS $BLDGTXT_CPPFLAGS" \
    LDFLAGS="-L$BLDGTXT_COMPILED/gettext/lib" \
    ac_cv_func__set_invalid_parameter_handler=no
bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-make"
echo '### Making gettext'
make $BLDGTXT_MAKE_JOBS --directory=gettext-tools --no-keep-going $BLDGTXT_QUIET_MAKE
echo '### Installing gettext'
make $BLDGTXT_MAKE_JOBS --directory=gettext-tools --no-keep-going $BLDGTXT_QUIET_MAKE DESTDIR=$BLDGTXT_COMPILED install

echo '### Creating output contents'
perl -pe 's/\r\n|\n|\r/\r\n/g' < $BLDGTXT_SOURCE/libiconv-$BLDGTXT_V_ICONV/COPYING > $BLDGTXT_OUTPUT/iconv-license.txt
perl -pe 's/\r\n|\n|\r/\r\n/g' < $BLDGTXT_SOURCE/gettext-$BLDGTXT_V_GETTEXT/COPYING > $BLDGTXT_OUTPUT/gettext-license.txt
unzip -p $BLDGTXT_ARCHIVES/cldr.zip unicode-license.txt | perl -pe 's/\r\n|\n|\r/\r\n/g' > $BLDGTXT_OUTPUT/cldr-license.txt

mkdir $BLDGTXT_OUTPUT/bin
for i in $(find $BLDGTXT_COMPILED/gettext/bin/ -name '*.exe' -o -name '*.dll'); do
    copyBinary $i
done

mkdir $BLDGTXT_OUTPUT/lib
cp $BLDGTXT_COMPILED/gettext/lib/charset.alias $BLDGTXT_OUTPUT/lib/
mkdir $BLDGTXT_OUTPUT/lib/gettext
copyBinary $BLDGTXT_COMPILED/gettext/lib/gettext/cldr-plurals.exe
for i in $(find $BLDGTXT_COMPILED/gettext/lib/gettext/ -name '*.dll'); do
    copyBinary $i
done

mkdir $BLDGTXT_OUTPUT/share
mkdir $BLDGTXT_OUTPUT/share/doc

mkdir $BLDGTXT_OUTPUT/share/doc/gettext
find $BLDGTXT_COMPILED/gettext/share/doc/gettext -maxdepth 1 -type f ! -iname '*.3.html' | xargs cp --target-directory=$BLDGTXT_OUTPUT/share/doc/gettext
rename 's/\.1\.html$/\.html/' '.html' $BLDGTXT_OUTPUT/share/doc/gettext/*.1.html

mkdir $BLDGTXT_OUTPUT/share/doc/libiconv
find $BLDGTXT_COMPILED/gettext/share/doc/libiconv -maxdepth 1 -type f ! -iname '*.3.html' | xargs cp --target-directory=$BLDGTXT_OUTPUT/share/doc/libiconv
rename 's/\.1\.html$/\.html/' '.html' $BLDGTXT_OUTPUT/share/doc/libiconv/*.1.html

cp --recursive $BLDGTXT_COMPILED/gettext/share/locale $BLDGTXT_OUTPUT/share/
mkdir $BLDGTXT_OUTPUT/share/gettext
cp --recursive $BLDGTXT_COMPILED/gettext/share/gettext-*/its $BLDGTXT_OUTPUT/share/gettext
cp --recursive $BLDGTXT_COMPILED/gettext/share/gettext/msgunfmt.tcl $BLDGTXT_OUTPUT/share/gettext

mkdir --parents $BLDGTXT_OUTPUT/lib/gettext/common/supplemental
unzip -p $BLDGTXT_ARCHIVES/cldr.zip common/supplemental/plurals.xml > $BLDGTXT_OUTPUT/lib/gettext/common/supplemental/plurals.xml

case $BLDGTXT_LINK$BLDGTXT_BITS in
    shared32)
        copyBinary $BLDGTXT_MXE/usr/${BLDGTXT_BITS2}-w64-mingw32.shared/bin/libstdc++-6.dll
        copyBinary $BLDGTXT_MXE/usr/${BLDGTXT_BITS2}-w64-mingw32.shared/bin/libgcc_s_sjlj-1.dll
        ;;
    shared64)
        copyBinary $BLDGTXT_MXE/usr/${BLDGTXT_BITS2}-w64-mingw32.shared/bin/libstdc++-6.dll
        copyBinary $BLDGTXT_MXE/usr/${BLDGTXT_BITS2}-w64-mingw32.shared/bin/libgcc_s_seh-1.dll
        ;;
esac
