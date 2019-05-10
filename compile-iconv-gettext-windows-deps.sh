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
