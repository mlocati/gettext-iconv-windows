[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'IconvVersion', Justification = 'Not used at this time, but it is passed for future use')]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $Bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $Link,
    [Parameter(Mandatory = $true)]
    [ValidateSet('gcc', 'msvc')]
    [string] $Compiler,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $InstalledPath,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $ToolsPath,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $CLDRVersion,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $IconvVersion,
    [Parameter(Mandatory = $false)]
    [string] $CurlVersionDefault,
    [Parameter(Mandatory = $false)]
    [string] $JsonCVersionDefault,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $GettextVersion,
    [Parameter(Mandatory = $false)]
    [string] $SignpathSigningPolicyDefault
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/functions.ps1"

function Join-Arguments {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [string[]] $ArgumentList
    )
    if (-not $ArgumentList) {
        return ''
    }
    if ($ArgumentList.Count -eq 0) {
        return ''
    }
    if ($ArgumentList.Count -eq 1) {
        return $ArgumentList[0]
    }
    return "\`n  " + ($ArgumentList -join " \`n  ")
}


# General configuration

$absoluteInstalledPath = [System.IO.Path]::Combine($(Get-Location), $InstalledPath)
if (-not(Select-String -InputObject $absoluteInstalledPath -Pattern '^([A-Za-z]):(\\.*?)\\?$')) {
    throw "Invalid value of InstalledPath '$InstalledPath' (resolved to '$absoluteInstalledPath')"
}
$cygwinInstalledPath = ConvertTo-CygwinPath -WindowsPath $absoluteInstalledPath.TrimEnd('\')
$absoluteToolsPath = [System.IO.Path]::Combine($(Get-Location), $ToolsPath)
if (-not(Select-String -InputObject $absoluteToolsPath -Pattern '^([A-Za-z]):(\\.*?)\\?$')) {
    throw "Invalid value of ToolsPath '$ToolsPath' (resolved to '$absoluteToolsPath')"
}
$cygwinToolsPath = ConvertTo-CygwinPath -WindowsPath $absoluteToolsPath.TrimEnd('\')

switch ($Bits) {
    32 {
        $mingwArchitecture = 'i686'
    }
    64 {
        $mingwArchitecture = 'x86_64'
    }
}
$mingwHost = "$mingwArchitecture-w64-mingw32"

$cygwinPackages = @(
    'file'
    'make'
    'unzip'
    'patch'
)
$cygwinPath = @(
    "$cygwinInstalledPath/bin"
)

$includeEnvVar = ''
$libEnvVar = ''

if ($Compiler -eq 'gcc') {
    $cygwinPackages += @(
        "mingw64-$mingwArchitecture-gcc-core"
        "mingw64-$mingwArchitecture-gcc-g++"
        "mingw64-$mingwArchitecture-headers"
        "mingw64-$mingwArchitecture-runtime"
    )
    if ($JsonCVersionDefault) {
        $cygwinPackages += 'cmake'
    }
    $cygwinPath += @(
        "/usr/$mingwHost/bin"
        "/usr/$mingwHost/sys-root/mingw/bin"
    )
    $cc = "/usr/bin/$mingwHost-gcc"
    $cxx = "/usr/bin/$mingwHost-g++"
    $ld = "/usr/bin/$mingwHost-ld"
    $nm = "/usr/bin/$mingwHost-nm"
    $strip = "/usr/bin/$mingwHost-strip"
    $ar = "/usr/bin/$mingwHost-ar"
    $ranlib = "/usr/bin/$mingwHost-ranlib"
    $cppFlags = @(
        "-I$cygwinInstalledPath/include"
        "-I/usr/$mingwHost/sys-root/mingw/include"
        '-DWINVER=0x0601'
        '-D_WIN32_WINNT=0x0601'
    )
    $cFlags = @(
        '-g0'
        '-O2'
    )
    $cxxFlags = @(
        '-g0'
        '-O2'
        '-fno-exceptions'
        '-fno-rtti'
    )
    $ldFlags = @(
        "-L$cygwinInstalledPath/lib"
        "-L/usr/$mingwHost/sys-root/mingw/lib"
    )
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
        $cxxFlags += '-fno-threadsafe-statics'
    }
    if ($Bits -eq 32 -and $Link -eq 'shared') {
        $ldFlags += ' -static-libgcc'
    }
    $makeInstallArgument = 'install-strip'
    $SignpathSigningPolicy = $SignpathSigningPolicyDefault
    $CollectPrograms = $true
} elseif ($Compiler -eq 'msvc') {
    $vcvars = [VCVars]::new($Bits)
    $cygwinPackages += @(
        "mingw64-$mingwArchitecture-binutils" # iconv requires windres
        "mingw64-$mingwArchitecture-gcc-core" # windres requires gcc
    )

    foreach ($p in $vcvars.GetPathDirs()) {
        $cygwinPath += ConvertTo-CygwinPath -WindowsPath $p
    }
    $includeEnvVar = $vcvars.GetIncludeDirs() -join ';'
    $libEnvVar = $vcvars.GetLibDirs() -join ';'
    $cc = "'$cygwinToolsPath/compile cl -nologo'"
    $cxx = "'$cygwinToolsPath/compile cl -nologo'"
    $ld = 'link'
    $nm = "'dumpbin -symbols'"
    $strip = ':'
    $ar = "'$cygwinToolsPath/ar-lib lib'"
    $ranlib = ':'
    $cppFlags = @(
        '-DWINVER=0x0601'
        '-D_WIN32_WINNT=_WIN32_WINNT_WIN7'
        "-I$cygwinInstalledPath/include"
    )
    $cFlags = @(
        '-MD'
    )
    $cxxFlags = @(
        '-MD'
    )
    $ldFlags = @(
        "-L$cygwinInstalledPath/lib"
    )
    $makeInstallArgument = 'install'
    if ($Link -eq 'shared') {
        $SignpathSigningPolicy = $SignpathSigningPolicyDefault
    } else {
        $SignpathSigningPolicy = ''
    }
    $CollectPrograms = $false
} else {
    throw "Unsupported compiler '$Compiler'"
}

$cygwinPath += @(
    '/usr/sbin'
    '/usr/bin'
    '/sbin'
    '/bin'
    '/cygdrive/c/Windows/System32'
    '/cygdrive/c/Windows'
)


# CLDR configuration

# See https://savannah.gnu.org/bugs/?func=detailitem&item_id=66378
$cldrSimplifyPluralsXml = (Compare-Versions $CLDRVersion '38') -ge 0 -and (Compare-Versions $GettextVersion '1.0') -lt 0
# See https://savannah.gnu.org/bugs/?66356
$cldrPluralWorks = ($Link -ne 'shared') -or (Compare-Versions $GettextVersion '0.23') -ge 0


# iconv configuration

$iconvConfigureArgs = @(
    "CC=$cc"
    "CXX=$cxx"
    "LD=$ld"
    "NM=$nm"
    "STRIP=$strip"
    "AR=$ar"
    "RANLIB=$ranlib"
    "CPPFLAGS='$($cppFlags -join ' ')'"
    "CFLAGS='$($cFlags -join ' ')'"
    "CXXFLAGS='$($cxxFlags -join ' ')'"
    "LDFLAGS='$($ldFlags -join ' ')'"
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
if ($CurlVersionDefault -and $Compiler -eq 'gcc') {
    $CurlVersion = $CurlVersionDefault
    $curlConfigureArgs = @(
        "CC=$cc"
        "CXX=$cxx"
        "LD=$ld"
        "NM=$nm"
        "STRIP=$strip"
        "AR=$ar"
        "RANLIB=$ranlib"
        "CPPFLAGS='$($cppFlags -join ' ')'"
        "CFLAGS='$($cFlags -join ' ')'"
        "CXXFLAGS='$($cxxFlags -join ' ')'"
        "LDFLAGS='$($ldFlags -join ' ')'"
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
} else {
    $CurlVersion = ''
}


# JSON-C configuration

$jsonCCMakeArgs = @()
if ($JsonCVersionDefault -and $Compiler -eq 'gcc') {
    $JsonCVersion = $JsonCVersionDefault
    $jsonCCMakeArgs = @(
        "-DCMAKE_C_COMPILER=$cc"
        "-DCMAKE_CXX_COMPILER=$cxx"
        "-DCMAKE_LINKER=$ld"
        "-DCMAKE_NM=$nm"
        "-DCMAKE_STRIP=$strip"
        "-DCMAKE_AR=$ar"
        "-DCMAKE_RANLIB=$ranlib"
        "-DCMAKE_C_FLAGS='$(($cppFlags + $cFlags) -join ' ')'"
        "-DCMAKE_CXX_FLAGS='$(($cppFlags + $cxxFlags) -join ' ')'"
        "-DCMAKE_SHARED_LINKER_FLAGS='$($ldFlags -join ' ')'"
        "-DCMAKE_EXE_LINKER_FLAGS='$($ldFlags -join ' ')'"
        '-DCMAKE_SYSTEM_NAME=Windows'
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
} else {
    $JsonCVersion = ''
}


# Gettext configuration

$gettextCPPFlags = $cppFlags -join ' '
if ($CurlVersion -and $Link -eq 'static' -and $Compiler -eq 'gcc') {
    $gettextCPPFlags += ' -DCURL_STATICLIB'
}
$gettextConfigureArgs = @(
    "CC=$cc"
    "CXX=$cxx"
    "LD=$ld"
    "NM=$nm"
    "STRIP=$strip"
    "AR=$ar"
    "RANLIB=$ranlib"
    "CPPFLAGS='$gettextCPPFlags'"
    "CFLAGS='$($cFlags -join ' ')'"
    "CXXFLAGS='$($cxxFlags -join ' ')'"
    "LDFLAGS='$($ldFlags -join ' ')'"
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
    '--disable-openmp'
    '--disable-curses'
    '--without-emacs'
    '--with-included-libxml'
    '--without-bzip2'
    '--without-xz'
)
if ($Compiler -eq 'msvc') {
    $gettextConfigureArgs += '--with-included-libunistring'
}
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
$checkSpitExe = $Compiler -eq 'gcc' -and (Compare-Versions $GettextVersion '1.0') -ge 0
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
Add-GithubOutput -Name 'include-env-var' -Value $includeEnvVar
Add-GithubOutput -Name 'lib-env-var' -Value $libEnvVar
Add-GithubOutput -Name 'make-install-argument' -Value $makeInstallArgument
Add-GithubOutput -Name 'iconv-configure-args' -Value $(Join-Arguments $iconvConfigureArgs)
Add-GithubOutput -Name 'curl-version' -Value $CurlVersion
Add-GithubOutput -Name 'curl-configure-args' -Value $(Join-Arguments $curlConfigureArgs)
Add-GithubOutput -Name 'json-c-version' -Value $JsonCVersion
Add-GithubOutput -Name 'json-c-cmake-args' -Value $(Join-Arguments $jsonCCMakeArgs)
Add-GithubOutput -Name 'gettext-configure-args' -Value $(Join-Arguments $gettextConfigureArgs)
Add-GithubOutput -Name 'gettext-ignore-c-tests' -Value $($gettextIgnoreCTests -join ' ')
Add-GithubOutput -Name 'gettext-xfail-gettext-tools' -Value $($gettextXFailTests -join ' ')
Add-GithubOutput -Name 'check-spit-exe' -Value $(if ($checkSpitExe) { 'yes' } else { 'no' })
Add-GithubOutput -Name 'signpath-signing-policy' -Value $SignpathSigningPolicy
Add-GithubOutput -Name 'collect-programs' -Value $(if ($CollectPrograms) { 'yes' } else { 'no' })

Write-Output '## Outputs'
Get-GitHubOutputs
