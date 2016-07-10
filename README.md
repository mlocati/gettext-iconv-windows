gettext-iconv-windows
=====================

gettext and iconv binaries for Windows.

## Ready-to-use binaries ##
If you don't want to waste your time or if you don't know much about compiling and virtual machines,  
see [mlocati.github.io/articles/gettext-iconv-windows.html](http://mlocati.github.io/articles/gettext-iconv-windows.html).

## Do you want to build binaries on your own? ##

### Compilation

I used [Ubuntu](http://www.ubuntu.com/) 16.04 LTS under [VirtualBox](https://www.virtualbox.org/)).

Get the `compile-iconv-gettext-windows.sh` and the `patches` directory (they must reside in the same directory).

Run the `compile-iconv-gettext-windows.sh` script to build the Windows binary files.

### Creating the setup files

I used a Windows machine (a physical Windows 10 64 bit) with [Inno Setup](http://www.jrsoftware.org/isinfo.php) (I used version 5.5.9-unicode).

---

Steps to compile (to be done under Linux):
- Run the `compile-iconv-gettext-windows.sh` script (the `patches` directory must be in the same directory as this script)
- following the instructions of the script you'll able to build the Windows executables

---

Steps to generate the setup files (to be done under Windows):

If you want to build a setup to install these executables and automatically add them to the environmental path:
- [take a copy](https://github.com/mlocati/gettext-iconv-windows/archive/master.zip) of the full repository gettext-iconv-windows
- under the folder containing the repository content, create a folder `compiled` and copy under that directory the `out-…` folder that you have under Linux
- launch the `build-setup.vbs` script


## Credits

The patch that adds support to the `GETTEXTIOENCODING` environmental variable was created by [Václav Slavík](https://github.com/vslavik/).
