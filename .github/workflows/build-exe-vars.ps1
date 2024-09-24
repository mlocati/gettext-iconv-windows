param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $link
)

$cygwinPackages = 'make,unzip,perl'

$gettextIgnoreTestsC = 'gettext-tools/gnulib-tests/test-asyncsafe-spin2.c gettext-tools/gnulib-tests/test-getopt-gnu.c gettext-tools/gnulib-tests/test-getopt-posix.c'

switch ($bits) {
    32 {
        $cygwinPackages = "$cygwinPackages,mingw64-i686-gcc-core,mingw64-i686-gcc-g++,mingw64-i686-headers,mingw64-i686-runtime"
        $mingwHost = 'i686-w64-mingw32'
    }
    64 {
        $cygwinPackages = "$cygwinPackages,mingw64-x86_64-gcc-core,mingw64-x86_64-gcc-g++,mingw64-x86_64-headers,mingw64-x86_64-runtime"
        $mingwHost = 'x86_64-w64-mingw32'
    }
}
switch ($link) {
    'shared' {
        $configureOptions = '--enable-shared --disable-static'
        $gettextCppFlags = ''
    }
    'static' {
        $configureOptions = '--disable-shared --enable-static'
        $gettextCppFlags = '-DLIBXML_STATIC'
    }
}
"cygwin-packages=$cygwinPackages" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"cygwin-path=/installed/bin:/usr/$mingwHost/bin:/usr/$mingwHost/sys-root/mingw/bin:/usr/sbin:/usr/bin:/sbin:/bin:/cygdrive/c/Windows/system32:/cygdrive/c/Windows" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"mingw-host=$mingwHost" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"configure-options=$configureOptions" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-cppflags=$gettextCppFlags" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
<# See https://savannah.gnu.org/bugs/?66232 #>
"gettext-ignore-tests-c=$gettextIgnoreTestsC" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
<# See https://savannah.gnu.org/bugs/?66232 #>
"gettext-xfail-tests=msgexec-1 msgexec-3 msgexec-4 msgexec-5 msgexec-6 msgfilter-6 msgfilter-7 msginit-3" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
Write-Output '## Outputs'
Get-Content $env:GITHUB_OUTPUT
