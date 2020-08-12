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
- Windows (cmd)
    ```bat
    docker run --rm -it -v "%CD%:/app" mlocati/gettext-iconv-windows:latest /app/compile-iconv-gettext-windows.sh
    ```
- Windows (PowerShell)
    ```PowerShell
    docker run --rm -it -v "$((Get-Location).Path):/app" mlocati/gettext-iconv-windows:latest /app/compile-iconv-gettext-windows.sh
    ```

To compile all the versions (shared and static, 32 and 64 bits), you can use the `compile-iconv-gettext-windows-all.sh` script.

## Building with a virtual machine or Ubuntu

The build script has been written for [Ubuntu](http://www.ubuntu.com/) 18.04 LTS.

Get the `*.sh` files and the `patches` directory (they must reside in the same directory).

Run the `compile-iconv-gettext-windows.sh` script to build the Windows binary files.

## Checking the compiled files

This requires a Windows PC.

- make sure the compiled files are in the directory `compiled\<shared|static>-<32|64>`
- launch the `check-dependencies.vbs` script (`cscript //Nologo check-dependencies.vbs`) 
- launch the `build-setup.vbs` script (`cscript //Nologo build-setup.vbs`)

## Creating the setup files

This requires a Windows PC with [Inno Setup](http://www.jrsoftware.org/isinfo.php) installed (I used version 5.5.9-unicode).

If you want to build a setup to install these executables and automatically add them to the environmental path:
- make sure the compiled files are in the directory `compiled\<shared|static>-<32|64>`
- launch the `build-setup.vbs` script

## Credits

The patch that adds support to the `GETTEXTIOENCODING` environmental variable was created by [Václav Slavík](https://github.com/vslavik/).

## Do you want to really say thank you?

You can offer me a [monthly coffee](https://github.com/sponsors/mlocati) or a [one-time coffee](https://paypal.me/mlocati) :wink:
