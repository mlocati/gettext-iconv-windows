[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'IconvVersion', Justification = 'Not used at this time, but it is passed for future use')]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $Bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $Link,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $InstalledPath,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $CLDRVersion,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $IconvVersion,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $GettextVersion,
    [Parameter(Mandatory = $false)]
    [string] $CurlVersion,
    [Parameter(Mandatory = $false)]
    [string] $JsonCVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/functions.ps1"

function Join-Arguments {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )
    if ($Arguments.Count -eq 0) {
        return ''
    }
    if ($Arguments.Count -eq 1) {
        return $Arguments[0]
    }
    return "\`n  " + ($Arguments -join " \`n  ")
}

# General configuration

$absoluteInstalledPath = [System.IO.Path]::Combine($(Get-Location), $InstalledPath)
$match = Select-String -InputObject $absoluteInstalledPath -Pattern '^([A-Za-z]):(\\.*?)\\?$'
if (!$match) {
    throw "Invalid value of InstalledPath '$InstalledPath' (resolved to '$absoluteInstalledPath')"
}
$cygwinInstalledPath = ConvertTo-CygwinPath -WindowsPath $absoluteInstalledPath.TrimEnd('\')
switch ($Bits) {
    32 {
        $mingwArchitecture = 'i686'
    }
    64 {
        $mingwArchitecture = 'x86_64'
    }
}
$mingwHost = "$mingwArchitecture-w64-mingw32"

$cppFlags = "-I$cygwinInstalledPath/include -I/usr/$mingwHost/sys-root/mingw/include -DWINVER=0x0601 -D_WIN32_WINNT=0x0601"
$cFlags = '-g0 -O2'
$cxxFlags = '-g0 -O2 -fno-exceptions -fno-rtti'
if ((Compare-Versions $GettextVersion '0.26') -lt 0 -or $GettextVersion -eq '0.26-pre1') {
    # We use -fno-threadsafe-statics because:
    # - otherwise xgettext would use the the __cxa_guard_acquire and __cxa_guard_release functions of lib-stdc++
    # - the only tool that uses multi-threading is msgmerge, which is in C (and not C++)
    # See:
    # - https://sourceforge.net/p/mingw-w64/mailman/message/58824383/
    # - https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00008.html
    # - https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00010.html
    # Since gettext 0.26 the -fno-threadsafe-statics is already the default:
    # see https://lists.gnu.org/archive/html/bug-gettext/2025-07/msg00019.html
    $cxxFlags += ' -fno-threadsafe-statics'
}
$ldFlags = "-L$cygwinInstalledPath/lib -L/usr/$mingwHost/sys-root/mingw/lib"
if ($Bits -eq 32 -and $Link -eq 'shared') {
    $ldFlags += ' -static-libgcc'
}


# Cygwin configuration

$cygwinPath = @(
    "$cygwinInstalledPath/bin"
    "/usr/$mingwHost/bin"
    "/usr/$mingwHost/sys-root/mingw/bin"
    '/usr/sbin'
    '/usr/bin'
    '/sbin'
    '/bin'
    '/cygdrive/c/Windows/System32'
    '/cygdrive/c/Windows'
)
$cygwinPackages = @(
    'file'
    'make'
    'unzip'
    'dos2unix'
    'patch'
    "mingw64-$mingwArchitecture-gcc-core"
    "mingw64-$mingwArchitecture-gcc-g++"
    "mingw64-$mingwArchitecture-headers"
    "mingw64-$mingwArchitecture-runtime"
)
if ($JsonCVersion) {
    $cygwinPackages += 'cmake'
}


# CLDR configuration

# See https://savannah.gnu.org/bugs/?func=detailitem&item_id=66378
$cldrSimplifyPluralsXml = (Compare-Versions $CLDRVersion '38') -ge 0 -and (Compare-Versions $GettextVersion '1.0') -lt 0
# See https://savannah.gnu.org/bugs/?66356
$cldrPluralWorks = ($Link -ne 'shared') -or (Compare-Versions $GettextVersion '0.23') -ge 0


# iconv configuration

$iconvConfigureArgs = @(
    "CPPFLAGS='$cppFlags'"
    "CFLAGS='$cFlags'"
    "CXXFLAGS='$cxxFlags'"
    "LDFLAGS='$ldFlags'"
    "--host=$mingwHost"
    "--prefix=$cygwinInstalledPath"
    '--enable-option-checking'
    '--config-cache'
    '--disable-dependency-tracking'
    '--enable-relocatable'
    '--enable-extra-encodings'
    '--disable-rpath'
    '--enable-year2038'
    '--enable-nls'
)
switch ($Link) {
    'shared' {
        $iconvConfigureArgs += @(
            '--enable-shared'
            '--disable-static'
        )
    }
    'static' {
        $iconvConfigureArgs += @(
            '--enable-static'
            '--disable-shared'
        )
    }
}


# Curl configuration

$curlConfigureArgs = @()
if ($CurlVersion) {
    $curlConfigureArgs = @(
        "CPPFLAGS='$cppFlags'"
        "CFLAGS='$cFlags'"
        "CXXFLAGS='$cxxFlags'"
        "LDFLAGS='$ldFlags'"
        "--host=$mingwHost"
        "--prefix=$cygwinInstalledPath"
        '--enable-option-checking'
        '--enable-http'
        '--disable-file'
        '--disable-ftp'
        '--disable-ldap'
        '--disable-ldaps'
        '--disable-rtsp'
        '--enable-proxy'
        '--disable-ipfs'
        '--disable-dict'
        '--disable-telnet'
        '--disable-tftp'
        '--disable-pop3'
        '--disable-imap'
        '--disable-smb'
        '--disable-smtp'
        '--disable-gopher'
        '--disable-mqtt'
        '--disable-websockets'
        '--disable-manual'
        '--disable-docs'
        '--enable-ipv6'
        '--enable-windows-unicode'
        '--disable-cookies'
        '--with-schannel'
        '--without-gnutls'
        '--without-openssl'
        '--without-rustls'
        '--without-wolfssl'
        '--without-libpsl'
        '--with-winidn'
        '--disable-threaded-resolver'
        '--disable-kerberos-auth'
        '--disable-ntlm'
        '--disable-negotiate-auth'
        '--disable-sspi'
        '--disable-unix-sockets'
        '--disable-dependency-tracking'
    )
    switch ($Link) {
        'shared' {
            $curlConfigureArgs += @(
                '--enable-shared'
                '--disable-static'
            )
        }
        'static' {
            $curlConfigureArgs += @(
                '--enable-static'
                '--disable-shared'
            )
        }
    }

}


# JSON-C configuration

$jsonCCMakeArgs = @()
if ($JsonCVersion) {
    $jsonCCMakeArgs = @(
        "-DCMAKE_C_FLAGS='$cFlags $cppFlags'"
        "-DCMAKE_CXX_FLAGS='$cxxFlags $cppFlags'"
        "-DCMAKE_SHARED_LINKER_FLAGS='$ldFlags'"
        '-DCMAKE_SYSTEM_NAME=Windows'
        "-DCMAKE_C_COMPILER=$mingwHost-gcc"
        "-DCMAKE_CXX_COMPILER=$mingwHost-g++"
        "-DCMAKE_INSTALL_PREFIX=$cygwinInstalledPath"
        '-DCMAKE_BUILD_TYPE=Release'
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
        '-DBUILD_TESTING=OFF'
        '-DDISABLE_THREAD_LOCAL_STORAGE=ON'
        '-DENABLE_THREADING=OFF'
        '-DBUILD_APPS=OFF'
    )
    switch ($Link) {
        'shared' {
            $jsonCCMakeArgs += @(
                '-DBUILD_SHARED_LIBS=ON'
                '-DBUILD_STATIC_LIBS=OFF'
            )
        }
        'static' {
            $jsonCCMakeArgs += @(
                '-DBUILD_STATIC_LIBS=ON'
                '-DBUILD_SHARED_LIBS=OFF'
            )
        }
    }
}


# Gettext configuration

$gettextCPPFlags = $cppFlags
if ($CurlVersion -and $Link -eq 'static') {
    $gettextCPPFlags += ' -DCURL_STATICLIB'
}
$gettextConfigureArgs = @(
    "CPPFLAGS='$gettextCPPFlags'"
    "CFLAGS='$cFlags'"
    "CXXFLAGS='$cxxFlags'"
    "LDFLAGS='$ldFlags'"
    "--host=$mingwHost"
    "--prefix=$cygwinInstalledPath"
    '--enable-option-checking'
    '--config-cache'
    '--disable-dependency-tracking'
    '--enable-relocatable'
    '--disable-rpath'
    '--enable-year2038'
    '--enable-nls'
    '--disable-acl'
    '--enable-threads=windows'
    '--disable-java'
    '--disable-native-java'
    '--disable-openmp'
    '--disable-curses'
    '--without-emacs'
    '--with-included-libxml'
    '--without-bzip2'
    '--without-xz'
)
if ((Compare-Versions $GettextVersion '0.22.5') -le 0) {
    $gettextConfigureArgs += '--disable-csharp'
} else {
    $gettextConfigureArgs += '--enable-csharp=dotnet'
    try {
        $dotnetCommand = Get-Command -Name dotnet.exe
    } catch {
        $dotnetCommand = $null
    }
    if (-not($dotnetCommand) -or -not($dotnetCommand.Path)) {
        throw 'Failed to find dotnet.exe'
    }
    $dotnetCommandPath = (Get-Item -Path ($dotnetCommand.Path)).Directory.FullName
    $cygwinPath += ConvertTo-CygwinPath -WindowsPath $dotnetCommandPath
}
switch ($Link) {
    'shared' {
        $gettextConfigureArgs += @(
            '--enable-shared'
            '--disable-static'
        )
    }
    'static' {
        $gettextConfigureArgs += @(
            '--enable-static'
            '--disable-shared'
        )
    }
}
$checkSpitExe = (Compare-Versions $GettextVersion '1.0') -ge 0
$gettextIgnoreCTests = @()
# see https://lists.gnu.org/archive/html/bug-gnulib/2024-09/msg00137.html
$gettextIgnoreCTests += 'gettext-tools/gnulib-tests/test-asyncsafe-spin2.c'
if ((Compare-Versions $GettextVersion '0.22.5') -le 0) {
    # see https://lists.gnu.org/archive/html/bug-gnulib/2024-09/msg00137.html
    $gettextIgnoreCTests += 'gettext-tools/gnulib-tests/test-getopt-gnu.c gettext-tools/gnulib-tests/test-getopt-posix.c'
}
$gettextXFailTests = @()
if ((Compare-Versions $GettextVersion '0.22.5') -le 0) {
    # see https://savannah.gnu.org/bugs/?66232
    $gettextXFailTests += 'msgexec-1 msgexec-3 msgexec-4 msgexec-5 msgexec-6 msgfilter-6 msgfilter-7 msginit-3'
}


# Export variables

Add-GithubOutput -Name 'cygwin-packages' -Value $($cygwinPackages -join ',')
Add-GithubOutput -Name 'cygwin-path' -Value $($cygwinPath -join ':')
Add-GithubOutput -Name 'mingw-architecture' -Value $mingwArchitecture
Add-GithubOutput -Name 'mingw-host' -Value $mingwHost
Add-GithubOutput -Name 'cldr-plural-works' -Value $(if ($cldrPluralWorks) { 'yes' } else { 'no' })
Add-GithubOutput -Name 'cldr-simplify-plurals-xml' -Value $(if ($cldrSimplifyPluralsXml) { 'yes' } else { 'no' })
Add-GithubOutput -Name 'iconv-configure-args' -Value $(Join-Arguments $iconvConfigureArgs)
Add-GithubOutput -Name 'curl-configure-args' -Value $(Join-Arguments $curlConfigureArgs)
Add-GithubOutput -Name 'json-c-cmake-args' -Value $(Join-Arguments $jsonCCMakeArgs)
Add-GithubOutput -Name 'gettext-configure-args' -Value $(Join-Arguments $gettextConfigureArgs)
Add-GithubOutput -Name 'gettext-ignore-c-tests' -Value $($gettextIgnoreCTests -join ' ')
Add-GithubOutput -Name 'gettext-xfail-gettext-tools' -Value $($gettextXFailTests -join ' ')
Add-GithubOutput -Name 'check-spit-exe' -Value $(if ($checkSpitExe) { 'yes' } else { 'no' })

Write-Output '## Outputs'
Get-GitHubOutputs
