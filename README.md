gettext-iconv-windows
=====================

gettext and iconv binaries for Windows.

## Ready-to-use binaries ##
If you don't want to waste your time or if you don't know much about compiling and virtual machines,  
see [mlocati.github.com/gettext-iconv-windows](https://mlocati.github.com/gettext-iconv-windows).

## Do you want to build binaries on your own? ##

Requirements:
- A Linux distro (I used [Debian](http://www.debian.org/) 7.1 32 bit under [VirtualBox](https://www.virtualbox.org/))
- To build the setup: a Windows machine (I used a physical Windows 7 64 bit) with [Inno Setup](http://www.jrsoftware.org/isinfo.php) (I used version 5.5.3-unicode)

---

Steps to compile (to be done under Linux):
- make sure you have the needed packages
	- to compile for 32 bit: `apt-get install binutils make wget mingw32 mingw32-runtime mingw32-binutils`
	- to compile for 64 bit: `apt-get install binutils make wget mingw-w64 mingw-w64-i686-dev mingw-w64-x86-64-dev`
- grab the [compile-iconv-gettext-windows.sh](https://raw.github.com/mlocati/gettext-iconv-windows/master/compile-iconv-gettext-windows.sh) script
- following the instructions of the script you'll able to build the Windows executables (they will be saved in the `build-gettext-windows/out-…/bin` folder in your home directory)

---

If you want to build a setup to install these executables and automatically add them to the environmental path:
- [take a copy](https://github.com/mlocati/gettext-iconv-windows/archive/master.zip) of the full repository gettext-iconv-windows
- under the folder containing the repository content, create a folder `compiled` and copy under that directory the `out-…` folder that you have under Linux
- With Inno Setup create the setup using the appropriate `setup-…-….iss` script you find in the repo folder


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/mlocati/gettext-iconv-windows/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

