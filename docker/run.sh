#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOTDIR="$(dirname "$DIR")"
sudo docker run --rm -v $ROOTDIR:/home/giw -v $ROOTDIR/compiled:/root/build-gettext-windows \
	-it ubuntu:18.04 bash -c \
	"apt update && \
	apt install sudo && \
	cd /home/giw && \
	./compile-iconv-gettext-windows-all.sh"

