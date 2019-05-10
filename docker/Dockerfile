FROM ubuntu:18.04

ADD https://raw.githubusercontent.com/mlocati/gettext-iconv-windows/master/compile-iconv-gettext-windows-deps.sh /compile-iconv-gettext-windows-deps.sh

RUN chmod uga+x /compile-iconv-gettext-windows-deps.sh && sync && \
    /compile-iconv-gettext-windows-deps.sh && \
    rm /compile-iconv-gettext-windows-deps.sh
