#!/bin/bash

set -o errexit
#set -o pipefail
set -o nounset
#set -o xtrace

if test -z "${BLDGTXT_MXE:-}"; then
    BLDGTXT_MXE=$HOME/mxe
fi

if test -d "$BLDGTXT_MXE/usr/bin" ; then
    echo '### Requirements already installed'
else
    echo '### Installing required libraries'
    if test "${UID:-}" == '0'; then
        BLDGTXT_SUDO=''
    else
        BLDGTXT_SUDO='sudo'
    fi
    $BLDGTXT_SUDO apt-get update
    $BLDGTXT_SUDO apt-get install -y \
        autoconf \
        automake \
        autopoint \
        bash \
        bison \
        bzip2 \
        flex \
        g++ \
        g++-multilib \
        gettext \
        git \
        gperf \
        intltool \
        libc6-dev-i386 \
        libgdk-pixbuf2.0-dev \
        libltdl-dev \
        libssl-dev \
        libtool-bin \
        libxml-parser-perl \
        lzip \
        make \
        openssl \
        p7zip-full \
        patch \
        perl \
        pkg-config \
        python \
        rename \
        ruby \
        scons \
        sed \
        unzip \
        wget \
        xz-utils
    rm -rf "$BLDGTXT_MXE"
    echo '### Downloading MXE'
    git clone https://github.com/mxe/mxe.git "$BLDGTXT_MXE"
    echo '### Building MXE (IT WILL TAKE UP TO ONE HOUR)'
    pushd "$BLDGTXT_MXE" >/dev/null
    make \
        MXE_TARGETS='i686-w64-mingw32.static i686-w64-mingw32.shared x86_64-w64-mingw32.static x86_64-w64-mingw32.shared' \
        cc
    popd >/dev/null
fi
echo '### checking automake version'
BLDGTXT_AUTOMAKE_VERSION_INSTALL='1.16.1'
BLDGTXT_AUTOMAKE_VERSION_MIN='1.16.0'
BLDGTXT_AUTOMAKE_VERSION_CUR="$(automake --version | head -n 1 | sed 's/^[^0-9]*//')"
BLDGTXT_AUTOMAKE_VERSION_CHECK=$(printf '%s\n%s' "$BLDGTXT_AUTOMAKE_VERSION_CUR" "$BLDGTXT_AUTOMAKE_VERSION_MIN" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)
if test "$BLDGTXT_AUTOMAKE_VERSION_CHECK" = "$BLDGTXT_AUTOMAKE_VERSION_MIN"; then
    printf ' - good (required: %s, found: %s)\n' "$BLDGTXT_AUTOMAKE_VERSION_MIN" "$BLDGTXT_AUTOMAKE_VERSION_CUR"
else
    printf ' - upgrading from %s to %s\n' "$BLDGTXT_AUTOMAKE_VERSION_CUR" "$BLDGTXT_AUTOMAKE_VERSION_INSTALL"
    $BLDGTXT_SUDO apt-get remove --purge -y automake
    pushd "$HOME" >/dev/null
    wget "ftp://ftp.gnu.org/gnu/automake/automake-$BLDGTXT_AUTOMAKE_VERSION_INSTALL.tar.gz"
    tar -xzf "automake-$BLDGTXT_AUTOMAKE_VERSION_INSTALL.tar.gz"
    rm "automake-$BLDGTXT_AUTOMAKE_VERSION_INSTALL.tar.gz"
    cd "automake-$BLDGTXT_AUTOMAKE_VERSION_INSTALL"
    ./configure
    make
    $BLDGTXT_SUDO make install
    cd ..
    rm -rf "automake-$BLDGTXT_AUTOMAKE_VERSION_INSTALL"
    popd >/dev/null
fi
