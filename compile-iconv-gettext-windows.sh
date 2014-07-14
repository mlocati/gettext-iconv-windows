#!/bin/sh
# Configuration:
# Cygwin under Windows:
# 	Downloaded setup-x86.exe from http://cygwin.com/install.html
# 	Installed with these packages
# 		Devel/binutils
# 		Devel/make
# 		Web/wget
# 		Devel/patch (** NEEDED IF COMPILING gettext 0.18.3 **)
# 		Devel/automake (** NEEDED IF COMPILING gettext 0.18.3 **)
# 		Devel/mingw-gcc-g++ (** NEEDED IF COMPILING FOR 32 bit **)
# 		Devel/mingw-w32api (** NEEDED IF COMPILING FOR 32 bit **)
# 		Devel/mingw64-x86_64-g++ (** NEEDED IF COMPILING FOR 64 bit **)
# Debian
#	Basic packages
# 		apt-get install binutils make wget
#	If compiling gettext 0.18.3 you need also
#		apt-get patch automake
# 	To compile for 32 bit:
# 		apt-get install mingw32 mingw32-runtime mingw32-binutils
# 	To compile for 64 bit:
# 		apt-get install mingw-w64 mingw-w64-i686-dev mingw-w64-x86-64-dev

######################
BLDGTXT_ROOT=~/build-gettext-windows
BLDGTXT_ARC=$BLDGTXT_ROOT/archives

BLDGTXT_VERS_ICONV=
BLDGTXT_VERS_GETTEXT=
BLDGTXT_BITS=
BLDGTXT_HOW=
while [ ! -z "$1" ]; do
	key="$1"
	shift
	case $key in
		-i|--iconv)
			BLDGTXT_VERS_ICONV=$1
			shift
			;;
		-g|--gettext)
			BLDGTXT_VERS_GETTEXT=$1
			shift
			;;
		-b|--bits)
			BLDGTXT_BITS=$1
			shift
			;;
		-w|--how)
			BLDGTXT_HOW=$1
			shift
			;;
		-h|--help)
			echo "Usage: $0 [-i|--iconv <iconv version>] [-g|--gettext <gettext version>] [-b|--bits <32|64>] [-w|--how <shared|static>]"
			exit 0
			;;
		*)
			echo "Unknown option: $key" >&2
			echo "Type $0 -h for help" >&2
			exit 1
	esac
done

if [ -z "$BLDGTXT_VERS_ICONV" ]; then
	BLDGTXT_VERS_ICONV=1.14
	echo "libiconv version [$BLDGTXT_VERS_ICONV]:"
	read BLDGTXT_TMP
	if [ ! -z "$BLDGTXT_TMP" ]; then
		BLDGTXT_VERS_ICONV=$BLDGTXT_TMP
	fi
else
	echo "libiconv version: $BLDGTXT_VERS_ICONV"
fi

if [ -z "$BLDGTXT_VERS_GETTEXT" ]; then
	BLDGTXT_VERS_GETTEXT=0.19.2
	echo "gettext version [$BLDGTXT_VERS_GETTEXT]:"
	read BLDGTXT_TMP
	if [ ! -z "$BLDGTXT_TMP" ]; then
		BLDGTXT_VERS_GETTEXT=$BLDGTXT_TMP
	fi
else
	echo "gettext version: $BLDGTXT_VERS_GETTEXT"
fi

if [ -z "$BLDGTXT_BITS" ]; then
	BLDGTXT_BITS=32
	echo "Architecture (32 for 32bit, 64 for 64bit) [$BLDGTXT_BITS]:"
	read BLDGTXT_TMP
	if [ ! -z "$BLDGTXT_TMP" ]; then
		BLDGTXT_BITS=$BLDGTXT_TMP
	fi
else
	echo "Architecture: $BLDGTXT_BITS bits"
fi
case $BLDGTXT_BITS in
	"32")
		if [ -d /usr/i686-pc-mingw32/sys-root/mingw ]; then
			BLDGTXT_BASE=/usr/i686-pc-mingw32/sys-root/mingw
			BLDGTXT_HOST=i686-pc-mingw32
		else
			if [ -d /usr/i586-mingw32msvc ]; then
				BLDGTXT_BASE=/usr/i586-mingw32msvc
				BLDGTXT_HOST=i586-mingw32msvc
			else
				echo mingw 32 bit not found. >&2
				exit 1
			fi
		fi
		;;
	"64")
		if [ -d /usr/x86_64-w64-mingw32/sys-root/mingw ]; then
			BLDGTXT_BASE=/usr/x86_64-w64-mingw32/sys-root/mingw
			BLDGTXT_HOST=x86_64-w64-mingw32
		else
			if [ -d /usr/x86_64-w64-mingw32 ]; then
				BLDGTXT_BASE=/usr/x86_64-w64-mingw32
				BLDGTXT_HOST=x86_64-w64-mingw32
			else
				echo mingw 64 bit not found. >&2
				exit 1
			fi
		fi
		;;
	*)
		echo "Unsupported bits: $BLDGTXT_BITS" >&2
		exit 1
		;;
esac

if [ -z "$BLDGTXT_HOW" ]; then
	BLDGTXT_HOW=shared
	echo "Shared (smaller but with DLL) or static (no DLL but bigger) build ('shared' or 'static') [$BLDGTXT_HOW]:"
	read BLDGTXT_TMP
	if [ ! -z "$BLDGTXT_TMP" ]; then
		BLDGTXT_HOW=$BLDGTXT_TMP
	fi
else
	echo "Compile as: $BLDGTXT_HOW"
fi

case $BLDGTXT_HOW in
	"shared")
		BLDGTXT_HOW_EXPANDED=" --enable-shared --enable-static "
		;;
	"static")
		BLDGTXT_HOW_EXPANDED=" --disable-shared --enable-static "
		;;
	*)
		echo "Unsupported build type: $BLDGTXT_HOW" >&2
		exit 1
		;;
esac

######################
BLDGTXT_SRC=$BLDGTXT_ROOT/src-$BLDGTXT_HOW-$BLDGTXT_BITS
BLDGTXT_DST=$BLDGTXT_ROOT/out-$BLDGTXT_HOW-$BLDGTXT_BITS
######################
echo Setup source archives

mkdir --parents $BLDGTXT_ARC

if [ ! -f "$BLDGTXT_ARC/libiconv-$BLDGTXT_VERS_ICONV.tar.gz" ]; then
	wget --output-document=$BLDGTXT_ARC/libiconv-$BLDGTXT_VERS_ICONV.tar.gz http://ftp.gnu.org/pub/gnu/libiconv/libiconv-$BLDGTXT_VERS_ICONV.tar.gz
	if [ $? -ne 0 ]; then
		echo "Error downloading libiconv $BLDGTXT_VERS_ICONV" >&2
		exit 1
	fi
fi

if [ ! -f "$BLDGTXT_ARC/gettext-$BLDGTXT_VERS_GETTEXT.tar.gz" ]; then
	wget --output-document=$BLDGTXT_ARC/gettext-$BLDGTXT_VERS_GETTEXT.tar.gz http://ftp.gnu.org/pub/gnu/gettext/gettext-$BLDGTXT_VERS_GETTEXT.tar.gz
	if [ $? -ne 0 ]; then
		echo "Error downloading gettext $BLDGTXT_VERS_GETTEXT" >&2
		exit 1
	fi
fi

if [ $BLDGTXT_VERS_GETTEXT = "0.18.3" ]; then
	if [ ! -f "$BLDGTXT_ARC/0001-Fix-AC_CHECK_DECLS-usage.patch" ]; then
		echo "--- a/gettext-runtime/m4/intl.m4
+++ b/gettext-runtime/m4/intl.m4
@@ -1,4 +1,4 @@
-# intl.m4 serial 23 (gettext-0.18.3)
+# intl.m4 serial 24 (gettext-0.18.3)
 dnl Copyright (C) 1995-2013 Free Software Foundation, Inc.
 dnl This file is free software; the Free Software Foundation
 dnl gives unlimited permission to copy and/or distribute it,
@@ -61,7 +61,7 @@ AC_DEFUN([AM_INTL_SUBDIR],
 
   dnl Use the _snprintf function only if it is declared (because on NetBSD it
   dnl is defined as a weak alias of snprintf; we prefer to use the latter).
-  AC_CHECK_DECLS([_snprintf _snwprintf], , , [#include <stdio.h>])
+  AC_CHECK_DECLS([_snprintf, _snwprintf], , , [#include <stdio.h>])
 
   dnl Use the *_unlocked functions only if they are declared.
   dnl (because some of them were defined without being declared in Solaris
@@ -234,7 +234,7 @@ AC_DEFUN([gt_INTL_SUBDIR_CORE],
   dnl (because some of them were defined without being declared in Solaris
   dnl 2.5.1 but were removed in Solaris 2.6, whereas we want binaries built
   dnl on Solaris 2.5.1 to run on Solaris 2.6).
-  AC_CHECK_DECLS([feof_unlocked fgets_unlocked], , , [#include <stdio.h>])
+  AC_CHECK_DECLS([feof_unlocked, fgets_unlocked], , , [#include <stdio.h>])
 
   AM_ICONV
 
--
" >"$BLDGTXT_ARC/0001-Fix-AC_CHECK_DECLS-usage.patch"
	fi
fi


######################
echo Clean up
cd $BLDGTXT_ROOT
rm --recursive --force $BLDGTXT_SRC
rm --recursive --force $BLDGTXT_DST
mkdir --parents $BLDGTXT_SRC
mkdir --parents $BLDGTXT_DST


######################
echo Compile iconv
cd $BLDGTXT_SRC
tar zxvf $BLDGTXT_ARC/libiconv-$BLDGTXT_VERS_ICONV.tar.gz
if [ $? -ne 0 ]; then
	echo "Error extracting libiconv archive" >&2
	exit 1
fi
cd libiconv-$BLDGTXT_VERS_ICONV
./configure --prefix=$BLDGTXT_DST --host=$BLDGTXT_HOST $BLDGTXT_HOW_EXPANDED CC="$BLDGTXT_HOST-gcc" CCX="$BLDGTXT_HOST-g++" CPPFLAGS="-Wall -I$BLDGTXT_BASE/include" LDFLAGS="-L$BLDGTXT_BASE/lib"
if [ $? -ne 0 ]; then
	echo "libiconv configure failed" >&2
	exit 1
fi
make install
if [ $? -ne 0 ]; then
	echo "libiconv make install failed" >&2
	exit 1
fi


######################
echo Compile gettext
cd $BLDGTXT_SRC
tar zxvf $BLDGTXT_ARC/gettext-$BLDGTXT_VERS_GETTEXT.tar.gz
if [ $? -ne 0 ]; then
	echo "Error extracting gettext archive" >&2
	exit 1
fi
cd gettext-$BLDGTXT_VERS_GETTEXT
if [ $BLDGTXT_VERS_GETTEXT = "0.18.3" ]; then
	echo Compile gettext - Start patch
	patch -p1 < "$BLDGTXT_ARC/0001-Fix-AC_CHECK_DECLS-usage.patch"
	if [ $? -ne 0 ]; then
		echo "Error patching gettext" >&2
		exit 1
	fi
	echo Compile gettext - Regenerate build scripts
	cd gettext-runtime
	aclocal -I m4 -I ../m4 -I gnulib-m4
	if [ $? -ne 0 ]; then
		echo "aclocal failed on patched gettext-runtime" >&2
		exit 1
	fi
	autoconf
	if [ $? -ne 0 ]; then
		echo "autoconf failed on patched gettext-runtime" >&2
		exit 1
	fi
	autoheader
	if [ $? -ne 0 ]; then
		echo "autoheader failed on patched gettext-runtime" >&2
		exit 1
	fi
	cd ..
	cd gettext-tools
	aclocal -I m4 -I ../gettext-runtime/m4 -I ../m4 -I gnulib-m4 -I libgrep/gnulib-m4 -I libgettextpo/gnulib-m4
	if [ $? -ne 0 ]; then
		echo "aclocal failed on patched gettext-tools" >&2
		exit 1
	fi
	autoconf
	if [ $? -ne 0 ]; then
		echo "autoconf failed on patched gettext-tools" >&2
		exit 1
	fi
	autoheader
	if [ $? -ne 0 ]; then
		echo "autoheader failed on patched gettext-tools" >&2
		exit 1
	fi
	automake --add-missing --copy
	if [ $? -ne 0 ]; then
		echo "automake failed on patched gettext-tools" >&2
		exit 1
	fi
	cd ..
	echo Compile gettext - End patch
fi
./configure --prefix=$BLDGTXT_DST --host=$BLDGTXT_HOST $BLDGTXT_HOW_EXPANDED CC="$BLDGTXT_HOST-gcc" CCX="$BLDGTXT_HOST-g++" CPPFLAGS="-Wall -I$BLDGTXT_BASE/include" LDFLAGS="-L$BLDGTXT_BASE/lib"
if [ $? -ne 0 ]; then
	echo "gettext configure failed" >&2
	exit 1
fi
make install
if [ $? -ne 0 ]; then
	echo "gettext make install failed" >&2
	exit 1
fi
echo All done. See $BLDGTXT_DST/bin
exit 0
