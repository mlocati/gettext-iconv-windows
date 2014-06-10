#!/bin/sh

./compile-iconv-gettext-windows.sh --iconv 1.14 --gettext 0.19.1 --bits 32 --how shared
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi

./compile-iconv-gettext-windows.sh --iconv 1.14 --gettext 0.19.1 --bits 32 --how static
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi

./compile-iconv-gettext-windows.sh --iconv 1.14 --gettext 0.19.1 --bits 64 --how shared
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi

./compile-iconv-gettext-windows.sh --iconv 1.14 --gettext 0.19.1 --bits 64 --how static
if [ $? -ne 0 ]; then
	echo "Error!" >&2
	exit 1
fi
