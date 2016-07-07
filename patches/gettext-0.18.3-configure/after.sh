#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

cd gettext-runtime
aclocal -I m4 -I ../m4 -I gnulib-m4
autoconf
autoheader
cd ..
cd gettext-tools
aclocal -I m4 -I ../gettext-runtime/m4 -I ../m4 -I gnulib-m4 -I libgrep/gnulib-m4 -I libgettextpo/gnulib-m4
autoconf
autoheader
automake --add-missing --copy
cd ..
