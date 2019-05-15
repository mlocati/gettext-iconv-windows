#!/bin/bash

#
# Script tested on a clean install of Ubuntu Server 18.04.2 LTS
#

set -ue # u: nounset, e: errexit
#set -o xtrace

#
# Get the directory where this script resides
#
# Output:
#   full path to the directory containing this script
#
bldgtxtGetSourceFolder () {
    set -ue
    pushd . >/dev/null
    local DIR="${BASH_SOURCE[0]}";
    while (test -h "$DIR" ) do
        cd "`dirname "$DIR"`"
        DIR="$(readlink "`basename "$DIR"`")";
    done
    cd "`dirname "$DIR"`" >/dev/null
    pwd
    popd >/dev/null
}

#
# Unset unneeded environment variables and set the default values
#
bldgtxtSetupEnvVars () {
    set -ue
    unset `env | grep -vi '^EDITOR=\|^HOME=\|^LANG=\|MXE\|^PATH=' | grep -vi 'PKG_CONFIG\|PROXY\|^PS1=\|^TERM=' | cut -d '=' -f1 | tr '\n' ' '`
    BLDGTXT_SCRIPTDIR="$(bldgtxtGetSourceFolder)"
    BLDGTXT_ROOT="$HOME/build-gettext-windows"
    BLDGTXT_V_ICONV_DEFAULT='1.16'
    BLDGTXT_V_ICONV=
    BLDGTXT_V_GETTEXT_DEFAULT='0.20.1'
    BLDGTXT_V_GETTEXT=
    BLDGTXT_LINK_DEFAULT=static
    BLDGTXT_LINK=
    BLDGTXT_BITS_DEFAULT=32
    BLDGTXT_BITS=
    BLDGTXT_OUTPUT_DEFAULT_TEMPLATE="$BLDGTXT_SCRIPTDIR/compiled/<link>-<bits>"
    BLDGTXT_OUTPUT=
    BLDGTXT_OUTPUT_FORCE=0
    BLDGTXT_MXE=$HOME/mxe
    BLDGTXT_QUIET=0
    BLDGTXT_DEBUGBUILD=0
    BLDGTXT_ARCHIVES="$BLDGTXT_SCRIPTDIR/archives"
    BLDGTXT_PATCHES="$BLDGTXT_SCRIPTDIR/patches"
    export PATH=$BLDGTXT_MXE/usr/bin:$PATH
    BLDGTXT_CONFIGURE_OPTIONS='--enable-relocatable --prefix=/gettext'
    BLDGTXT_CONFIGURE_OPTIONS_ICONV='--config-cache --disable-dependency-tracking --disable-nls --disable-rpath'
    BLDGTXT_CONFIGURE_OPTIONS_GETTEXT='--config-cache --disable-dependency-tracking --disable-java --disable-native-java --disable-csharp --disable-rpath --disable-openmp --disable-curses --without-emacs --disable-acl --enable-threads=windows --with-included-libxml --without-bzip2 --without-xz ac_cv_func__set_invalid_parameter_handler=no'
    BLDGTXT_MAKE_OPTIONS='--no-keep-going'
    BLDGTXT_MAKE_OPTIONS_ICONV=
    BLDGTXT_MAKE_OPTIONS_GETTEXT=
    # CPPFLAGS
    BLDGTXT_FLAGS_PREPROCESSOR='-D__USE_MINGW_ANSI_STDIO=0'
    BLDGTXT_FLAGS_PREPROCESSOR_ICONV=
    BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT=
    # CFLAGS
    BLDGTXT_FLAGS_C=
    BLDGTXT_FLAGS_C_ICONV=
    BLDGTXT_FLAGS_C_GETTEXT=
    # CXXFLAGS
    BLDGTXT_FLAGS_CPP=
    BLDGTXT_FLAGS_CPP_ICONV=
    BLDGTXT_FLAGS_CPP_GETTEXT=
    # LDFLAGS
    BLDGTXT_FLAGS_LINKER=
    BLDGTXT_FLAGS_LINKER_ICONV=
    BLDGTXT_FLAGS_LINKER_GETTEXT=
    # LIBTOOLFLAGS
    BLDGTXT_FLAGS_LIBTOOL=
    BLDGTXT_FLAGS_LIBTOOL_ICONV=
    BLDGTXT_FLAGS_LIBTOOL_GETTEXT=
}

#
# Set the environment variables that are configuration specific
#
bldgtxtSetupEnvVarsPostConfig () {
    set -ue
    if test -z "$BLDGTXT_V_ICONV"; then
        read -p "iconv version [$BLDGTXT_V_ICONV_DEFAULT]: " BLDGTXT_V_ICONV
        if test -z "$BLDGTXT_V_ICONV"; then
            BLDGTXT_V_ICONV="$BLDGTXT_V_ICONV_DEFAULT"
        fi
    fi
    if test -z "$BLDGTXT_V_GETTEXT"; then
        read -p "gettext version [$BLDGTXT_V_GETTEXT_DEFAULT]: " BLDGTXT_V_GETTEXT
        if test -z "$BLDGTXT_V_GETTEXT"; then
            BLDGTXT_V_GETTEXT="$BLDGTXT_V_GETTEXT_DEFAULT"
        fi
    fi
    if test -z "$BLDGTXT_LINK"; then
        read -p "Link (shared for smaller but with DLL, static for no DLL but bigger results) [$BLDGTXT_LINK_DEFAULT]: " BLDGTXT_LINK
        if test -z "$BLDGTXT_LINK"; then
            BLDGTXT_LINK="$BLDGTXT_LINK_DEFAULT"
        fi
    fi
    case "$BLDGTXT_LINK" in
        shared )
            BLDGTXT_CONFIGURE_OPTIONS="$BLDGTXT_CONFIGURE_OPTIONS --enable-shared --disable-static"
            ;;
        static )
            BLDGTXT_CONFIGURE_OPTIONS="$BLDGTXT_CONFIGURE_OPTIONS --disable-shared --enable-static"
            BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT="$BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT -DLIBXML_STATIC"
            ;;
        * )
            printf "Invalid link specified (%s)\nValid values are: shared, static\n" "$BLDGTXT_LINK" >&2
            return 1
            ;;
    esac
    if test -z "$BLDGTXT_BITS"; then
        read -p "Architecture (32 for 32bit, 64 for 64bit) [$BLDGTXT_BITS_DEFAULT]: " BLDGTXT_BITS
        if test -z "$BLDGTXT_BITS"; then
            BLDGTXT_BITS="$BLDGTXT_BITS_DEFAULT"
        fi
    fi
    case "$BLDGTXT_BITS" in
        32 )
            BLDGTXT_BITS2=i686
            ;;
        64 )
            BLDGTXT_BITS2=x86_64
            ;;
        * )
            printf "Invalid architecture specified (%s)\nValid values are: 32, 64\n" "$BLDGTXT_BITS" >&2
            return 1
            ;;
    esac
    BLDGTXT_OUTPUT_DEFAULT=$(printf '%s' "$BLDGTXT_OUTPUT_DEFAULT_TEMPLATE" | sed "s/<link>/$BLDGTXT_LINK/" | sed "s/<bits>/$BLDGTXT_BITS/")
    if test "$BLDGTXT_OUTPUT" = '-'; then
        BLDGTXT_OUTPUT=
    elif test -z "$BLDGTXT_OUTPUT"; then
        read -p "Output directory [$BLDGTXT_OUTPUT_DEFAULT]: " BLDGTXT_OUTPUT
    fi
    if test -z "$BLDGTXT_OUTPUT"; then
        BLDGTXT_OUTPUT="$BLDGTXT_OUTPUT_DEFAULT"
    fi
    if test -d "$BLDGTXT_OUTPUT"; then
        if test $BLDGTXT_OUTPUT_FORCE -ne 1; then
            printf 'The output directory "%s" already exists.\nSpecify the --force option to use it anyway\n' "$BLDGTXT_OUTPUT" >&2
            exit 1
        fi
    fi
    BLDGTXT_BASEDIR="$BLDGTXT_ROOT/$BLDGTXT_LINK-$BLDGTXT_BITS"
    BLDGTXT_SOURCE="$BLDGTXT_BASEDIR/source"
    BLDGTXT_CONFIGURED="$BLDGTXT_BASEDIR/configured"
    BLDGTXT_COMPILED="$BLDGTXT_BASEDIR/compiled"
    BLDGTXT_BINUTILSPREFIX="$BLDGTXT_BITS2-w64-mingw32.$BLDGTXT_LINK-"

    if test $BLDGTXT_QUIET -eq 1; then
        BLDGTXT_CONFIGURE_OPTIONS="$BLDGTXT_CONFIGURE_OPTIONS --quiet --enable-silent-rules"
        BLDGTXT_FLAGS_PREPROCESSOR="$BLDGTXT_FLAGS_PREPROCESSOR -Wno-int-to-pointer-cast -Wno-attributes -Wno-write-strings"
        BLDGTXT_FLAGS_C="$BLDGTXT_FLAGS_C -Wno-pointer-to-int-cast -Wno-incompatible-pointer-types"
        BLDGTXT_MAKE_OPTIONS="$BLDGTXT_MAKE_OPTIONS -silent --jobs=$(nproc)"
        BLDGTXT_FLAGS_LIBTOOL="$BLDGTXT_FLAGS_LIBTOOL --silent" 
    else
        BLDGTXT_MAKE_OPTIONS="$BLDGTXT_MAKE_OPTIONS --jobs=1"
    fi
    export MXE_TARGETS="${BLDGTXT_BITS2}-w64-mingw32.${BLDGTXT_LINK}"
    export PKG_CONFIG_PATH="$BLDGTXT_COMPILED"
    BLDGTXT_PKG_CONFIG_PATH_NAME="PKG_CONFIG_PATH_${BLDGTXT_BITS2}_w64_mingw32_${BLDGTXT_LINK}"
    export $BLDGTXT_PKG_CONFIG_PATH_NAME=$PKG_CONFIG_PATH
    unset BLDGTXT_PKG_CONFIG_PATH_NAME
    BLDGTXT_CONFIGURE_OPTIONS="$BLDGTXT_CONFIGURE_OPTIONS --host=$MXE_TARGETS"
    BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT="$BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT -I$BLDGTXT_COMPILED/gettext/include"
    BLDGTXT_FLAGS_LINKER_GETTEXT="$BLDGTXT_FLAGS_LINKER_GETTEXT -L$BLDGTXT_COMPILED/gettext/lib"
    if test $BLDGTXT_DEBUGBUILD -eq 1; then
        BLDGTXT_FLAGS_PREPROCESSOR="$BLDGTXT_FLAGS_PREPROCESSOR -g3"
    else
        BLDGTXT_FLAGS_PREPROCESSOR="$BLDGTXT_FLAGS_PREPROCESSOR -g0 -O2"
    fi
}

#
# Prints out the build configuration
#
bldgtxtPrintConfiguration () {
    set -ue
    echo '### Configuration'
    printf 'iconv version     : %s\n' "$BLDGTXT_V_ICONV"
    printf 'gettext version   : %s\n' "$BLDGTXT_V_GETTEXT"
    printf 'No. of bits       : %s\n' "$BLDGTXT_BITS"
    printf 'Link              : %s\n' "$BLDGTXT_LINK"
    printf 'Output directory  : %s\n' "$BLDGTXT_OUTPUT"
    echo '### Shared options'
    printf 'configure         : %s\n' "${BLDGTXT_CONFIGURE_OPTIONS# }"
    printf 'make              : %s\n' "${BLDGTXT_MAKE_OPTIONS# }"
    printf 'Preprocessor flags: %s\n' "${BLDGTXT_FLAGS_PREPROCESSOR# }"
    printf 'C flags           : %s\n' "${BLDGTXT_FLAGS_C# }"
    printf 'C++ flags         : %s\n' "${BLDGTXT_FLAGS_CPP# }"
    printf 'Linker flags      : %s\n' "${BLDGTXT_FLAGS_LINKER# }"
    printf 'libtool flags     : %s\n' "${BLDGTXT_FLAGS_LIBTOOL# }"
    echo '### iconv-specific options'
    printf 'configure         : %s\n' "${BLDGTXT_CONFIGURE_OPTIONS_ICONV# }"
    printf 'make              : %s\n' "${BLDGTXT_MAKE_OPTIONS_ICONV# }"
    printf 'Preprocessor flags: %s\n' "${BLDGTXT_FLAGS_PREPROCESSOR_ICONV# }"
    printf 'C flags           : %s\n' "${BLDGTXT_FLAGS_C_ICONV# }"
    printf 'C++ flags         : %s\n' "${BLDGTXT_FLAGS_CPP_ICONV# }"
    printf 'Linker flags      : %s\n' "${BLDGTXT_FLAGS_LINKER_ICONV# }"
    printf 'libtool flags     : %s\n' "${BLDGTXT_FLAGS_LIBTOOL_ICONV# }"
    echo '### gettext-specific options'
    printf 'configure         : %s\n' "${BLDGTXT_CONFIGURE_OPTIONS_GETTEXT# }"
    printf 'make              : %s\n' "${BLDGTXT_MAKE_OPTIONS_GETTEXT# }"
    printf 'Preprocessor flags: %s\n' "${BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT# }"
    printf 'C flags           : %s\n' "${BLDGTXT_FLAGS_C_GETTEXT# }"
    printf 'C++ flags         : %s\n' "${BLDGTXT_FLAGS_CPP_GETTEXT# }"
    printf 'Linker flags      : %s\n' "${BLDGTXT_FLAGS_LINKER_GETTEXT# }"
    printf 'libtool flags     : %s\n' "${BLDGTXT_FLAGS_LIBTOOL_GETTEXT# }"
}

#
# Install required apt packages and prepares MXE (if not already present)
#
bldgtxtRequirements () {
    set -ue
    "$BLDGTXT_SCRIPTDIR/compile-iconv-gettext-windows-deps.sh"
}

#
# Display an invalid argument error
#
# Arguments:
#     $1: error message
#
bldgtxtShowInvalidArgument () {
    set -ue
    printf '%s\n\n%s\n' "${1}" "Type $0 --help to get help" >&2
}

#
# Output the command syntax
#
bldgtxtShowUsage () {
    set -ue
    printf 'Usage: %s [-i|--iconv <-|iconv version>] [-g|--gettext <-|gettext version>] [-b|--bits <-|32|64>] [-l|--link <-|shared|static>] [-o|--output <-|dir>] [-f|--force] [-q|--quiet] [d|--debug]\n' "$0"
    printf 'Default iconv version: %s\n' "$BLDGTXT_V_ICONV_DEFAULT"
    printf 'Default gettext version: %s\n' "$BLDGTXT_V_GETTEXT_DEFAULT"
    printf 'Default bits: %s\n' "$BLDGTXT_BITS_DEFAULT"
    printf 'Default link: %s\n' "$BLDGTXT_LINK_DEFAULT"
    printf 'Default output directory: %s\n' "$BLDGTXT_OUTPUT_DEFAULT_TEMPLATE"
    echo 'Use the --quiet flag to be less verbose'
    echo 'Use the --debug flag to keep debug symbols included in the binary files'
}

#
# Parse the command arguments and exits in case of errors
#
# Arguments:
#     $@: all the command line parameters
#
bldgtxtReadCommandLine () {
    set -ue
    local CURRENT_ARGUMENT
    local NEXT_ARGUMENT
    while test $# -gt 0 ; do
        CURRENT_ARGUMENT="$1"
        NEXT_ARGUMENT="${2:-}"
        shift 1
        case "$CURRENT_ARGUMENT" in
            -h | --help )
                bldgtxtShowUsage
                exit 0
                ;;
            -i | --iconv )
                if test -n "$BLDGTXT_V_ICONV"; then
                    bldgtxtShowInvalidArgument 'iconv version specified more than once'
                    exit 1
                fi
                if test -z "$NEXT_ARGUMENT"; then
                    bldgtxtShowInvalidArgument 'Missing iconv version'
                    exit 1
                fi
                if test "$NEXT_ARGUMENT" = '-'; then
                    BLDGTXT_V_ICONV="$BLDGTXT_V_ICONV_DEFAULT"
                else
                    BLDGTXT_V_ICONV="$NEXT_ARGUMENT"
                fi
                shift 1
                ;;
            -g | --gettext )
                if test -n "$BLDGTXT_V_GETTEXT"; then
                    bldgtxtShowInvalidArgument 'gettext version specified more than once'
                    exit 1
                fi
                if test -z "$NEXT_ARGUMENT"; then
                    bldgtxtShowInvalidArgument 'Missing gettext version'
                    exit 1
                fi
                if test "$NEXT_ARGUMENT" = '-'; then
                    BLDGTXT_V_GETTEXT="$BLDGTXT_V_GETTEXT_DEFAULT"
                else
                    BLDGTXT_V_GETTEXT="$NEXT_ARGUMENT"
                fi
                shift 1
                ;;
            -b | --bits )
                if test -n "$BLDGTXT_BITS"; then
                    bldgtxtShowInvalidArgument 'Architecture specified more than once'
                    exit 1
                fi
                if test -z "$NEXT_ARGUMENT"; then
                    bldgtxtShowInvalidArgument "Missing architecture (32 or 64)"
                    exit 1
                fi
                if test "$NEXT_ARGUMENT" = '-'; then
                    BLDGTXT_BITS="$BLDGTXT_BITS_DEFAULT"
                else
                    BLDGTXT_BITS="$NEXT_ARGUMENT"
                fi
                shift 1
                ;;
            -l | --link )
                if test -n "$BLDGTXT_LINK"; then
                    bldgtxtShowInvalidArgument 'Link specified more than once'
                    exit 1
                fi
                if test -z "$NEXT_ARGUMENT"; then
                    bldgtxtShowInvalidArgument "Missing link (shared or static)"
                    exit 1
                fi
                if test "$NEXT_ARGUMENT" = '-'; then
                    BLDGTXT_LINK="$BLDGTXT_LINK_DEFAULT"
                else
                    BLDGTXT_LINK="$NEXT_ARGUMENT"
                fi
                shift 1
                ;;
            -o | --output )
                if test -n "$BLDGTXT_OUTPUT"; then
                    bldgtxtShowInvalidArgument 'Output directory specified more than once'
                    exit 1
                fi
                if test -z "$NEXT_ARGUMENT"; then
                    bldgtxtShowInvalidArgument 'Missing output directory'
                    exit 1
                fi
                BLDGTXT_OUTPUT="$NEXT_ARGUMENT"
                shift 1
                ;;
            -f | --force )
                BLDGTXT_OUTPUT_FORCE=1
                ;;
            -q | --quiet )
                BLDGTXT_QUIET=1
                ;;
            -d | --debug )
                BLDGTXT_DEBUGBUILD=1
                ;;
            * )
                bldgtxtShowInvalidArgument "Unrecognized option: $CURRENT_ARGUMENT"
                exit 1
        esac
    done
}

#
# Remove initial/final spaces from a string
#
# Arguments:
#     $1: the string to be trimmed
#
# Output:
#     The trimmed string
#
bldgtxtTrim () {
    set -ue
    local result="${1# }"
    while test "$result" != "${result# }"; do
        result="${result# }"
    done
    while test "$result" != "${result% }"; do
        result="${result% }"
    done
    printf '%s' "$result"
}

#
# Download a file (if it's not in the archives directory)
#
# Arguments:
#     $1 the URL to be downloaded
#     $2 the local file name
#
# Return value:
#     0: success
#     1: failure
#
bldgtxtDownloadArchive () {
    set -ue
    if test ! -f "$BLDGTXT_ARCHIVES/$2"; then
        printf 'Downloading %s\n' "$2"
        set +o errexit
        wget --quiet --tries=3 "--output-document=$BLDGTXT_ARCHIVES/$2" -- "$1" || {
            printf 'Failed to download %s\n' "$1" >&2
            rm "$BLDGTXT_ARCHIVES/$2" >/dev/null 2>&1
            set -o errexit
            return 1
        }
        set -o errexit
    fi
    return 0
}

#
# Ensures that we have a local copy of all the required remote archives
#
bldgtxtDownloadArchives () {
    set -ue
    echo '### Checking source archives'
    mkdir -p "$BLDGTXT_ARCHIVES"
    bldgtxtDownloadArchive "http://ftp.gnu.org/pub/gnu/libiconv/libiconv-$BLDGTXT_V_ICONV.tar.gz" "libiconv-$BLDGTXT_V_ICONV.tar.gz"
    bldgtxtDownloadArchive "http://ftp.gnu.org/pub/gnu/gettext/gettext-$BLDGTXT_V_GETTEXT.tar.gz" "gettext-$BLDGTXT_V_GETTEXT.tar.gz" \
        || bldgtxtDownloadArchive "https://alpha.gnu.org/gnu/gettext/gettext-$BLDGTXT_V_GETTEXT.tar.gz" "gettext-$BLDGTXT_V_GETTEXT.tar.gz"
    if test ! -f "$BLDGTXT_ARCHIVES/cldr.zip"; then
        bldgtxtDownloadArchive http://unicode.org/Public/cldr/latest/core.zip cldr.zip
        unzip -p "$BLDGTXT_ARCHIVES/cldr.zip" unicode-license.txt > "$BLDGTXT_ARCHIVES/cldr-license.txt"
        unzip -p $BLDGTXT_ARCHIVES/cldr.zip common/supplemental/plurals.xml > "$BLDGTXT_ARCHIVES/cldr-plurals.xml"
    fi
}

#
# Deletes the temporary compiled directory
#
bldgtxtDeleteCompiled () {
    set -ue
    rm -rf "$BLDGTXT_COMPILED"
}

#
# Apply a set of patches to the current directory
#
# Arguments:
#     $1 The source of the patch files
#
bldgtxtApplyPatches () {
    set -ue
    local PATCH_DIR=$1
    if test -d "$PATCH_DIR"; then
        local PATCH_BEFORE="$PATCH_DIR/before.sh"
        if test -f "$PATCH_BEFORE"; then
            echo " - before-patch step"
            bash "$PATCH_BEFORE"
        fi
        local PATCHES_PATTERN="$PATCH_DIR/*.patch"
        local PATCH_FILE
        for PATCH_FILE in $PATCHES_PATTERN; do
            printf ' - patching (%s)\n' "$(basename "$PATCH_FILE")"
            patch --strip=1 --input="$PATCH_FILE" --silent
        done
        local PATCH_AFTER="$PATCH_DIR/after.sh"
        if test -f "$PATCH_AFTER"; then
            echo " - after-patch step"
            bash "$PATCH_AFTER"
        fi
    fi
}

#
# Prepare the source code of iconv
#
bldgtxtPrepareIconv () {
    set -ue
    echo '### Preparing iconv'
    mkdir -p "$BLDGTXT_SOURCE"
    rm -rf "$BLDGTXT_SOURCE/libiconv-$BLDGTXT_V_ICONV"
    pushd "$BLDGTXT_SOURCE" >/dev/null
    tar xzf "$BLDGTXT_ARCHIVES/libiconv-$BLDGTXT_V_ICONV.tar.gz"
    cd "libiconv-$BLDGTXT_V_ICONV"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-configure"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-configure/$BLDGTXT_LINK"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-configure/$BLDGTXT_BITS"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-configure/$BLDGTXT_LINK-$BLDGTXT_BITS"
    popd >/dev/null
}

#
# Configure the source code of iconv
#
bldgtxtConfigureIconv () {
    set -ue
    echo '### Configuring iconv'
    rm -rf "$BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV"
    mkdir -p "$BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV"
    pushd "$BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV" >/dev/null
    "$BLDGTXT_SOURCE/libiconv-$BLDGTXT_V_ICONV/configure" \
        $BLDGTXT_CONFIGURE_OPTIONS \
        $BLDGTXT_CONFIGURE_OPTIONS_ICONV \
        CPPFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_PREPROCESSOR $BLDGTXT_FLAGS_PREPROCESSOR_ICONV")" \
        CFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_C $BLDGTXT_FLAGS_C_ICONV")" \
        CXXFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_CPP $BLDGTXT_FLAGS_CPP_ICONV")" \
        LDFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_LINKER $BLDGTXT_FLAGS_LINKER_ICONV")" \
        LIBTOOLFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_LIBTOOL $BLDGTXT_FLAGS_LIBTOOL_ICONV")"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-make"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-make/$BLDGTXT_LINK"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-make/$BLDGTXT_BITS"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/libiconv-$BLDGTXT_V_ICONV-make/$BLDGTXT_LINK-$BLDGTXT_BITS"
    popd >/dev/null
}

#
# Compile the source code of iconv
#
bldgtxtCompileIconv () {
    set -ue
    echo '### Making iconv'
    pushd "$BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV" >/dev/null
    make $BLDGTXT_MAKE_OPTIONS $BLDGTXT_MAKE_OPTIONS_ICONV
    popd >/dev/null
}

#
# Install iconv to the temporary compiled directory
#
bldgtxtInstallIconv () {
    set -ue
    echo '### Installing iconv'
    pushd "$BLDGTXT_CONFIGURED/libiconv-$BLDGTXT_V_ICONV" >/dev/null
    make $BLDGTXT_MAKE_OPTIONS $BLDGTXT_MAKE_OPTIONS_ICONV DESTDIR=$BLDGTXT_COMPILED install
    popd >/dev/null
}

#
# Prepare the source code of gettext
#
bldgtxtPrepareGettext () {
    set -ue
    echo '### Preparing gettext'
    mkdir -p "$BLDGTXT_SOURCE"
    rm -rf "$BLDGTXT_SOURCE/gettext-$BLDGTXT_V_GETTEXT"
    pushd "$BLDGTXT_SOURCE" >/dev/null
    tar xzf "$BLDGTXT_ARCHIVES/gettext-$BLDGTXT_V_GETTEXT.tar.gz"
    cd "gettext-$BLDGTXT_V_GETTEXT"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-configure"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-configure/$BLDGTXT_LINK"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-configure/$BLDGTXT_BITS"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-configure/$BLDGTXT_LINK-$BLDGTXT_BITS"
    popd >/dev/null
}

#
# Configure the source code of gettext
#
bldgtxtConfigureGettext () {
    set -ue
    echo '### Configuring gettext'
    rm -rf "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT"
    mkdir -p "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT"
    pushd "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT" >/dev/null
    "$BLDGTXT_SOURCE/gettext-$BLDGTXT_V_GETTEXT/configure" \
        $BLDGTXT_CONFIGURE_OPTIONS \
        $BLDGTXT_CONFIGURE_OPTIONS_GETTEXT \
        CPPFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_PREPROCESSOR $BLDGTXT_FLAGS_PREPROCESSOR_GETTEXT")" \
        CFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_C $BLDGTXT_FLAGS_C_GETTEXT")" \
        CXXFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_CPP $BLDGTXT_FLAGS_CPP_GETTEXT")" \
        LDFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_LINKER $BLDGTXT_FLAGS_LINKER_GETTEXT")" \
        LIBTOOLFLAGS="$(bldgtxtTrim "$BLDGTXT_FLAGS_LIBTOOL $BLDGTXT_FLAGS_LIBTOOL_GETTEXT")"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-make"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-make/$BLDGTXT_LINK"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-make/$BLDGTXT_BITS"
    bldgtxtApplyPatches "$BLDGTXT_PATCHES/gettext-$BLDGTXT_V_GETTEXT-make/$BLDGTXT_LINK-$BLDGTXT_BITS"
    popd >/dev/null
}

#
# Compile the source code of gettext
#
bldgtxtCompileGettext () {
    set -ue
    echo '### Making gettext'
    pushd "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT" >/dev/null
    if test -f "libtextstyle/Makefile"; then
        make $BLDGTXT_MAKE_OPTIONS $BLDGTXT_MAKE_OPTIONS_GETTEXT --directory=libtextstyle
    fi
    make $BLDGTXT_MAKE_OPTIONS $BLDGTXT_MAKE_OPTIONS_GETTEXT --directory=gettext-tools
    popd >/dev/null
}

#
# Install gettext to the temporary compiled directory
#
bldgtxtInstallGettext () {
    set -ue
    echo '### Installing gettext'
    pushd "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT" >/dev/null
    if test -f "libtextstyle/Makefile"; then
        make $BLDGTXT_MAKE_OPTIONS $BLDGTXT_MAKE_OPTIONS_GETTEXT --directory=libtextstyle DESTDIR=$BLDGTXT_COMPILED install
    fi
    make $BLDGTXT_MAKE_OPTIONS $BLDGTXT_MAKE_OPTIONS_GETTEXT --directory=gettext-tools DESTDIR=$BLDGTXT_COMPILED install
    popd >/dev/null
}

#
# Copy a file to the output directory
#
# Arguments:
#  $1: the full path to the source file
#  $2: special type (binary, text, doc). If omitted, no special operation will be performed
#  $3: the relative path of the destination file (if omitted we'll calculate it)
#
copyFileToOutput () {
    set -ue
    local SOURCE_PATH="$1"
    local COPY_TYPE="${2:-}"
    local RELATIVE_NAME="${3:-}"
    if test -z "$RELATIVE_NAME"; then
        RELATIVE_NAME="${SOURCE_PATH#${BLDGTXT_COMPILED}/gettext}"
    fi
    RELATIVE_NAME="${RELATIVE_NAME##/}"
    local DESTINATION_PATH="$BLDGTXT_OUTPUT/$RELATIVE_NAME"
    if test "$COPY_TYPE" = 'doc'; then
        local DESTINATION_PATH2
        DESTINATION_PATH2="${DESTINATION_PATH%.1.html}"
        if test "$DESTINATION_PATH" != "$DESTINATION_PATH2"; then
            DESTINATION_PATH="$DESTINATION_PATH2.html"
        fi
    fi
    mkdir -p "$(dirname "$DESTINATION_PATH")"
    case "$COPY_TYPE" in
        binary )
            if test $BLDGTXT_DEBUGBUILD -eq 1; then
                cp "$SOURCE_PATH" "$DESTINATION_PATH"
            else
                "${BLDGTXT_BINUTILSPREFIX}strip" --strip-unneeded "$SOURCE_PATH" -o "$DESTINATION_PATH"
            fi
            ;;
        text )
            perl -pe 's/\r\n|\n|\r/\r\n/g' < "$SOURCE_PATH" > "$DESTINATION_PATH"
            ;;
        * )
            cp "$SOURCE_PATH" "$DESTINATION_PATH"
            ;;
    esac
}

#
# Copy the files from the temporary compiled directory to the output directory
#
bldgtxtCopyToOutput () {
    set -ue
    echo '### Creating output contents'
    local i
    copyFileToOutput "$BLDGTXT_SOURCE/libiconv-$BLDGTXT_V_ICONV/COPYING" text iconv-license.txt
    copyFileToOutput "$BLDGTXT_SOURCE/gettext-$BLDGTXT_V_GETTEXT/COPYING" text gettext-license.txt
    copyFileToOutput "$BLDGTXT_ARCHIVES/cldr-license.txt" text cldr-license.txt
    for i in $(find "$BLDGTXT_COMPILED/gettext/bin/" -name '*.exe' -o -name '*.dll'); do
        copyFileToOutput "$i" binary
    done
    copyFileToOutput "$BLDGTXT_COMPILED/gettext/lib/gettext/cldr-plurals.exe" binary
    if test -f "$BLDGTXT_COMPILED/gettext/lib/charset.alias"; then
        copyFileToOutput "$BLDGTXT_COMPILED/gettext/lib/charset.alias"
    fi
    if test -d "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT/libtextstyle/lib/.libs/"; then
        for i in $(find "$BLDGTXT_CONFIGURED/gettext-$BLDGTXT_V_GETTEXT/libtextstyle/lib/.libs/" -name '*.dll'); do
            copyFileToOutput "$i" binary "bin/$(basename $i)"
        done
    fi
    for i in $(find "$BLDGTXT_COMPILED/gettext/share/doc" -maxdepth 2 -type f ! -iname '*.3.html' ! -iname 'autopoint.1.html' ! -iname 'gettextize.1.html'); do
        copyFileToOutput "$i" doc
    done
    mkdir -p "$BLDGTXT_OUTPUT/share/"
    cp -r "$BLDGTXT_COMPILED/gettext/share/locale" "$BLDGTXT_OUTPUT/share/"
    mkdir -p "$BLDGTXT_OUTPUT/share/gettext"
    if test -d "$BLDGTXT_COMPILED/gettext/share/gettext/styles"; then
        cp -r "$BLDGTXT_COMPILED/gettext/share/gettext/styles" "$BLDGTXT_OUTPUT/share/gettext/"
    fi
    cp -r $BLDGTXT_COMPILED/gettext/share/gettext-*/its $BLDGTXT_OUTPUT/share/gettext
    copyFileToOutput "$BLDGTXT_COMPILED/gettext/share/gettext/msgunfmt.tcl"
    copyFileToOutput "$BLDGTXT_ARCHIVES/cldr-plurals.xml" '' lib/gettext/common/supplemental/plurals.xml
    case $BLDGTXT_LINK$BLDGTXT_BITS in
        shared32 )
            copyFileToOutput "$BLDGTXT_MXE/usr/$MXE_TARGETS/bin/libgcc_s_sjlj-1.dll" '' bin/libgcc_s_sjlj-1.dll
            copyFileToOutput "$BLDGTXT_MXE/usr/$MXE_TARGETS/bin/libwinpthread-1.dll" '' bin/libwinpthread-1.dll
            copyFileToOutput "$BLDGTXT_MXE/usr/$MXE_TARGETS/bin/libstdc++-6.dll" '' bin/libstdc++-6.dll
            ;;
        shared64 )
            copyFileToOutput "$BLDGTXT_MXE/usr/$MXE_TARGETS/bin/libwinpthread-1.dll" '' bin/libwinpthread-1.dll
            copyFileToOutput "$BLDGTXT_MXE/usr/$MXE_TARGETS/bin/libstdc++-6.dll" '' bin/libstdc++-6.dll
            copyFileToOutput "$BLDGTXT_MXE/usr/$MXE_TARGETS/bin/libgcc_s_seh-1.dll" '' bin/libgcc_s_seh-1.dll
            echo 1
            ;;
    esac
}

bldgtxtSetupEnvVars
bldgtxtReadCommandLine "$@"
bldgtxtRequirements
bldgtxtSetupEnvVarsPostConfig
bldgtxtPrintConfiguration
bldgtxtDownloadArchives
bldgtxtDeleteCompiled
bldgtxtPrepareIconv
bldgtxtConfigureIconv
bldgtxtCompileIconv
bldgtxtInstallIconv
bldgtxtPrepareGettext
bldgtxtConfigureGettext
bldgtxtCompileGettext
bldgtxtInstallGettext
bldgtxtCopyToOutput
