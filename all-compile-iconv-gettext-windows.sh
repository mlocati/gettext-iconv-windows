#!/bin/sh
BLDGTXTALL_VERS_ICONV=1.14
BLDGTXTALL_VERS_GETTEXT=0.19.3

mydir=`dirname $0`
$mydir/compile-iconv-gettext-windows.sh --iconv $BLDGTXTALL_VERS_ICONV --gettext $BLDGTXTALL_VERS_GETTEXT --bits 32 --how shared
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi

$mydir/compile-iconv-gettext-windows.sh --iconv $BLDGTXTALL_VERS_ICONV --gettext $BLDGTXTALL_VERS_GETTEXT --bits 32 --how static
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi

$mydir/compile-iconv-gettext-windows.sh --iconv $BLDGTXTALL_VERS_ICONV --gettext $BLDGTXTALL_VERS_GETTEXT --bits 64 --how shared
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi

$mydir/compile-iconv-gettext-windows.sh --iconv $BLDGTXTALL_VERS_ICONV --gettext $BLDGTXTALL_VERS_GETTEXT --bits 64 --how static
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi
