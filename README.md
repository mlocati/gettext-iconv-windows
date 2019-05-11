![Github All Releases](https://img.shields.io/github/downloads/mlocati/gettext-iconv-windows/total.svg?style=flat-square)

# gettext-iconv-windows

gettext tools and iconv binaries for Windows.


## Ready-to-use binaries

If you don't want to waste your time or if you don't know much about compiling and virtual machines, see [mlocati.github.io/articles/gettext-iconv-windows.html](http://mlocati.github.io/articles/gettext-iconv-windows.html).


## Building with Docker

You can build the gettext/iconv binaries with [Docker](https://www.docker.com/).

Simply clone this repository, open a terminal and run this command:

- Linux/Mac:
    ```sh
    docker run --rm -it -v "$PWD:/app mlocati/gettext-iconv-windows:latest" /app/compile-iconv-gettext-windows.sh
    ```
- Windows
    ```bat
    docker run --rm -it -v "%CD%:/app" mlocati/gettext-iconv-windows:latest /app/compile-iconv-gettext-windows.sh
    ```

## Building with Virtual Machine or your Ubuntu

The build script has been written for [Ubuntu](http://www.ubuntu.com/) 18.04 LTS.

Get the `*.sh` files and the `patches` directory (they must reside in the same directory).

Run the `compile-iconv-gettext-windows.sh` script to build the Windows binary files.


## Creating the setup files

I used a Windows machine (a physical Windows 10 64 bit) with [Inno Setup](http://www.jrsoftware.org/isinfo.php) (I used version 5.5.9-unicode).

---

Steps to compile (to be done under Linux):
- Run the `compile-iconv-gettext-windows.sh` script (the `patches` directory must be in the same directory as this script)
- following the instructions of the script you'll able to build the Windows executables

---

Steps to generate the setup files (to be done under Windows):

If you want to build a setup to install these executables and automatically add them to the environmental path:
- [take a copy](https://github.com/mlocati/gettext-iconv-windows/archive/master.zip) of the full repository gettext-iconv-windows
- copy in the `compiled` directory the `<shared|static>-<32|64>` folder that you have under Linux
- launch the `build-setup.vbs` script


## Credits

The patch that adds support to the `GETTEXTIOENCODING` environmental variable was created by [Václav Slavík](https://github.com/vslavik/).
