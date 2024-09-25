# Script that sets some variables used in the GitHub Action steps

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $Bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $Link
)

if (-not($env:GETTEXT_VERSION)) {
    throw 'Missing GETTEXT_VERSION environment variable'
}

$cygwinPackages = 'make,unzip,perl'

$gettextIgnoreTestsC = 'gettext-tools/gnulib-tests/test-getopt-gnu.c gettext-tools/gnulib-tests/test-getopt-posix.c'

switch ($Bits) {
    32 {
        $cygwinPackages = "$cygwinPackages,mingw64-i686-gcc-core,mingw64-i686-gcc-g++,mingw64-i686-headers,mingw64-i686-runtime"
        $mingwHost = 'i686-w64-mingw32'
    }
    64 {
        $cygwinPackages = "$cygwinPackages,mingw64-x86_64-gcc-core,mingw64-x86_64-gcc-g++,mingw64-x86_64-headers,mingw64-x86_64-runtime"
        $mingwHost = 'x86_64-w64-mingw32'
    }
}

$configureArgs = @(
    "CC=$mingwHost-gcc",
    "CXX=$mingwHost-g++",
    "LD=$mingwHost-ld",
    "--host=$mingwHost",
    '--enable-relocatable',
    '--config-cache',
    '--disable-dependency-tracking',
    '--enable-nls',
    '--disable-rpath',
    '--disable-acl',
    '--enable-threads=windows'
)

switch ($Link) {
    'shared' {
        $configureArgs += '--enable-shared --disable-static'
    }
    'static' {
        $configureArgs += '--disable-shared --enable-static'
    }
}

if ([Version]($env:GETTEXT_VERSION -replace '[a.z]+$','') -le [Version]'0.22.5') {
    # See https://savannah.gnu.org/bugs/?66232
    $gettextXFailTests='msgexec-1 msgexec-3 msgexec-4 msgexec-5 msgexec-6 msgfilter-6 msgfilter-7 msginit-3'
} else {
    $gettextXFailTests=''
}

switch ($env:GETTEXT_VERSION) {
    '0.22.5a' {
        # see https://lists.gnu.org/archive/html/bug-gettext/2024-09/msg00039.html
        $gettextSourceUrl="https://alpha.gnu.org/gnu/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"
    }
    default {
        $gettextSourceUrl="https://ftp.gnu.org/pub/gnu/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"
    }
}

"cygwin-packages=$cygwinPackages" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"cygwin-path=/installed/bin:/usr/$mingwHost/bin:/usr/$mingwHost/sys-root/mingw/bin:/usr/sbin:/usr/bin:/sbin:/bin:/cygdrive/c/Windows/system32:/cygdrive/c/Windows" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"mingw-host=$mingwHost" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"configure-args=$configureArgs" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"cpp-flags=-I/usr/$mingwHost/sys-root/mingw/include -g0 -O2" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"ld-flags=-L/usr/$mingwHost/sys-root/mingw/lib" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
<# See https://savannah.gnu.org/bugs/?66232 #>
"gettext-source-url=$gettextSourceUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-ignore-tests-c=$gettextIgnoreTestsC" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-xfail-gettext-tools=$gettextXFailTests" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
Write-Output '## Outputs'
Get-Content $env:GITHUB_OUTPUT
