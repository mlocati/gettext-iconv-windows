[![Build](https://github.com/mlocati/gettext-iconv-windows/actions/workflows/build.yml/badge.svg)](https://github.com/mlocati/gettext-iconv-windows/actions/workflows/build.yml)
[![GitHub Releases](https://img.shields.io/github/downloads/mlocati/gettext-iconv-windows/total.svg?style=flat-square)](https://github.com/mlocati/gettext-iconv-windows/releases)

# iconv and gettext binaries and development files for Windows

The tools are built by the [`build` GitHub Action](https://github.com/mlocati/gettext-iconv-windows/actions/workflows/build.yml).

In addition to the Windows executables (msginit, xgettext, msgfmt, ...), this project also provides development files for MinGW/gcc and Microsoft Visual C (`.h`, `.a`, `.dll.a`, `.lib`, `.dll.lib` files).

For example, you have ready-to-use static libraries `libasprintf.a`, `libcharset.a`, `libgettextpo.a`, `libiconv.a`, `libintl.a`, `libtextstyle.a` (for MinGW-w64/gcc) and `asprintf.lib`, `charset.lib`, `gettextpo.lib`, `iconv.lib`, `intl.lib`, `textstyle.lib` (for MSVC) 2-bit and 64-bit systems.

You can download them from [the releases page](https://github.com/mlocati/gettext-iconv-windows/releases) or from the [project homepage](https://mlocati.github.io/articles/gettext-iconv-windows.html).

Please refer to the official manuals documentation: [here for iconv](https://www.gnu.org/software/libiconv/) and [here for gettext](https://www.gnu.org/software/gettext/).


## Code Signing Policy

Starting with gettext v0.22.5 / iconv v1.17, the built DLLs and executables are signed.

Free code signing is provided by [SignPath.io](https://about.signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

The source code of gettext and iconv is developed and maintained by the [Free Software Foundation](https://www.fsf.org/).

This gettext-iconv-windows project only compiles gettext and iconv for Windows, and is maintained by [Michele Locati](https://mlocati.github.io).

## Privacy policy

The gettext and iconv tools do not collect personal data: they are used solely for local work.
