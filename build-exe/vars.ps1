# Script that sets some variables used in the GitHub Action steps

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $Bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $Link,
    [Parameter(Mandatory = $true)]
    [string] $InstalledPath,
    [Parameter(Mandatory = $false)]
    [ValidateSet('', 'no', 'test', 'production')]
    [string] $Sign
)

function Export-Variable()
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $false)]
        [string] $Value
    )
    "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

function ConvertTo-Version()
{
    [OutputType([Version])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Version
    )
    if ($Version -match '^[0-9]+(\.[0-9]+)+') {
        return [Version]$matches[0]
    }
    throw "Invalid Version: '$Version'"
}

function ConvertTo-CygwinPath()
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $WindowsPath
    )
    $match = Select-String -InputObject $WindowsPath -Pattern '^([A-Za-z]):(\\.*)$'
    if (!$match) {
        throw "Invalid value of WindowsPath '$WindowsPath'"
    }
    return '/cygdrive/' + $match.Matches.Groups[1].Value.ToLowerInvariant() + $match.Matches.Groups[2].Value.Replace('\', '/')
}

if (-not($env:ICONV_VERSION)) {
    throw 'Missing ICONV_VERSION environment variable'
}
if (-not($env:GETTEXT_VERSION)) {
    throw 'Missing GETTEXT_VERSION environment variable'
}
$gettextVersion = ConvertTo-Version -Version $env:GETTEXT_VERSION
if (-not($env:CLDR_VERSION)) {
    throw 'Missing CLDR_VERSION environment variable'
}
$cldrMajorVersion = [int][regex]::Match($env:CLDR_VERSION, '^\d+').Value

$absoluteInstalledPath = [System.IO.Path]::Combine($(Get-Location), $InstalledPath)
$match = Select-String -InputObject $absoluteInstalledPath -Pattern '^([A-Za-z]):(\\.*?)\\?$'
if (!$match) {
    throw "Invalid value of InstalledPath '$InstalledPath' (resolved to '$absoluteInstalledPath')"
}
$cygwinInstalledPath = ConvertTo-CygwinPath -WindowsPath $absoluteInstalledPath.TrimEnd('\')

switch ($Bits) {
    32 {
        $architecture = 'i686'
    }
    64 {
        $architecture = 'x86_64'
    }
}

$mingwHost = "$architecture-w64-mingw32"

$cygwinPath = @(
    "$cygwinInstalledPath/bin",
    "/usr/$mingwHost/bin",
    "/usr/$mingwHost/sys-root/mingw/bin",
    '/usr/sbin',
    '/usr/bin',
    '/sbin',
    '/bin',
    '/cygdrive/c/Windows/System32',
    '/cygdrive/c/Windows'
)

$cygwinPackages = @(
    'file',
    'make',
    'unzip',
    'dos2unix',
    'patch',
    "mingw64-$architecture-gcc-core",
    "mingw64-$architecture-gcc-g++",
    "mingw64-$architecture-headers",
    "mingw64-$architecture-runtime"
)

$cFlags = '-g0 -O2'
$cxxFlags = '-g0 -O2'

$buildLibcurlVersion = ''
$buildLibcurlConfigureArgs = @()
$buildLibcurlCurlconfigArg = ''
$buildJsonCVersion = ''
$buildJsonCCMakeArgs = @()

if ($gettextVersion -ge [Version]'1.0') {
    # The spit program (introduced in gettext 1.0) requires libcurl and json-c (otherwise gettext builds a Python script)
    $cygwinPackages += 'cmake'
    $buildLibcurlVersion = '8.18.0'
    $buildLibcurlConfigureArgs = @(
        "CC='$mingwHost-gcc'",
        "CXX='$mingwHost-g++'",
        "LD='$mingwHost-ld'",
        "STRIP='$mingwHost-strip'",
        "CPPFLAGS='-I$cygwinInstalledPath/include -I/usr/$mingwHost/sys-root/mingw/include -DWINVER=0x0601 -D_WIN32_WINNT=0x0601'",
        "CFLAGS='-g0 -O2'",
        "CXXFLAGS='-g0 -O2'",
        "LDFLAGS='-L$cygwinInstalledPath/lib -L/usr/$mingwHost/sys-root/mingw/lib'",
        "--host=$mingwHost",
        '--enable-http',
        '--disable-ftp',
        '--enable-file',
        '--disable-ldap',
        '--disable-ldaps',
        '--disable-rtsp',
        '--enable-proxy',
        '--disable-ipfs',
        '--disable-dict',
        '--disable-telnet',
        '--disable-tftp',
        '--disable-pop3',
        '--disable-imap',
        '--disable-smb',
        '--disable-smtp',
        '--disable-gopher',
        '--disable-mqtt',
        '--disable-manual',
        '--disable-docs',
        '--enable-ipv6',
        '--enable-windows-unicode',
        '--disable-cookies',
        '--with-schannel',
        '--without-gnutls',
        '--without-openssl',
        '--without-rustls'
        '--without-wolfssl',
        '--without-libpsl',
        '--with-winidn',
        '--disable-threaded-resolver',
        '--disable-dependency-tracking',
        "--prefix=$cygwinInstalledPath"
    )
    $buildJsonCVersion = '0.18'
    $buildJsonCCMakeArgs = @(
        '-DCMAKE_BUILD_TYPE=Release',
        "'-DCMAKE_INSTALL_PREFIX=$cygwinInstalledPath'",
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
        '-DBUILD_TESTING=OFF',
        "-DCMAKE_C_COMPILER=$mingwHost-gcc",
        "-DCMAKE_C_FLAGS='-g0 -O2'"
    )
    switch ($Link) {
        'shared' {
            $buildLibcurlConfigureArgs += '--enable-shared'
            $buildLibcurlConfigureArgs += '--disable-static'
            $buildLibcurlCurlconfigArg = '--libs'
            $buildJsonCCMakeArgs += '-DBUILD_SHARED_LIBS=ON'
            $buildJsonCCMakeArgs += '-DBUILD_STATIC_LIBS=OFF'
        }
        'static' {
            $cFlags = "$cFlags -DCURL_STATICLIB"
            $buildLibcurlConfigureArgs += '--enable-static'
            $buildLibcurlConfigureArgs += '--disable-shared'
            $buildLibcurlCurlconfigArg = '--static-libs'
            $buildJsonCCMakeArgs += '-DBUILD_STATIC_LIBS=ON'
            $buildJsonCCMakeArgs += '-DBUILD_SHARED_LIBS=OFF'
        }
    }
}

if ($gettextVersion -lt [Version]'0.26' -or $env:GETTEXT_VERSION -eq '0.26-pre1') {
    # We use -fno-threadsafe-statics because:
    # - otherwise xgettext would use the the __cxa_guard_acquire and __cxa_guard_release functions of lib-stdc++
    # - the only tool that uses multi-threading is msgmerge, which is in C (and not C++)
    # See:
    # - https://sourceforge.net/p/mingw-w64/mailman/message/58824383/
    # - https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00008.html
    # - https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00010.html
    # Since gettext 0.26 the -fno-threadsafe-statics is already the default:
    # see https://lists.gnu.org/archive/html/bug-gettext/2025-07/msg00019.html
    $cxxFlags = "$cxxFlags -fno-threadsafe-statics"
}

$configureArgs = @(
    # The C compiler
    "CC='$mingwHost-gcc'",
    # The C++ compiler
    "CXX='$mingwHost-g++'",
    # The linker
    "LD='$mingwHost-ld'",
    # The strip command
    "STRIP='$mingwHost-strip'",
    # The C/C++ preprocessor flags
    "CPPFLAGS='-I$cygwinInstalledPath/include -I/usr/$mingwHost/sys-root/mingw/include -DWINVER=0x0601 -D_WIN32_WINNT=0x0601'",
    # The flags for the C compiler
    "CFLAGS='$cFlags'",
    # The flags for the C++ compiler
    "CXXFLAGS='$cxxFlags'",
    # The flags for the linker
    "LDFLAGS='-L$cygwinInstalledPath/lib -L/usr/$mingwHost/sys-root/mingw/lib'",
    "--host=$mingwHost",
    '--enable-relocatable',
    '--config-cache',
    '--disable-dependency-tracking',
    '--enable-nls',
    '--disable-rpath',
    '--disable-acl',
    '--enable-threads=windows',
    "--prefix=$cygwinInstalledPath"
)
switch ($Link) {
    'shared' {
        $configureArgs += '--enable-shared --disable-static'
    }
    'static' {
        $configureArgs += '--disable-shared --enable-static'
    }
}
$gettextConfigureArgs = @(
    '--disable-java',
    '--disable-native-java',
    '--disable-openmp',
    '--disable-curses',
    '--without-emacs',
    '--with-included-libxml',
    '--without-bzip2',
    '--without-xz'
)
if ($gettextVersion -le [Version]'0.22.5') {
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

if ($env:GITHUB_REPOSITORY -ne 'mlocati/gettext-iconv-windows') {
    Write-Host -Object "Using -Sign no because the current repository ($($env:GITHUB_REPOSITORY)) is not the upstream one`n"
    $Sign = 'no'
} elseif ($env:GITHUB_EVENT_NAME -eq 'pull_request') {
    Write-Host -Object "Using -Sign no because the current event is $($env:GITHUB_EVENT_NAME)`n"
    $Sign = 'no'
} elseif (-not($Sign)) {
    Write-Host -Object "Using -Sign test`n"
    $Sign = 'test'
}
$signpathSigningPolicy = ''
$signaturesCanBeInvalid = 0
switch ($Sign) {
    'no' {
        Write-Host "Signing is disabled`n"
    }
    'test' {
        $signpathSigningPolicy = 'test-signing'
        $signaturesCanBeInvalid = 1
        Write-Host "SignPath signing policy: $signpathSigningPolicy (self-signed certificate)`n"
    }
    'production' {
        $signpathSigningPolicy = 'release-signing'
        Write-Host "SignPath signing policy: $signpathSigningPolicy (production certificate)`n"
    }
    default {
        throw "Invalid value of the -Sign argument ($Sign)"
    }
}

if ($gettextVersion -le [Version]'0.22.5') {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-0.22'
} else {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-0.23'
}

$gettextIgnoreTestsC = @()
# see https://lists.gnu.org/archive/html/bug-gnulib/2024-09/msg00137.html
$gettextIgnoreTestsC += 'gettext-tools/gnulib-tests/test-asyncsafe-spin2.c'
if ($gettextVersion -le [Version]'0.22.5') {
    # see https://lists.gnu.org/archive/html/bug-gnulib/2024-09/msg00137.html
    $gettextIgnoreTestsC += 'gettext-tools/gnulib-tests/test-getopt-gnu.c gettext-tools/gnulib-tests/test-getopt-posix.c'
}

$gettextXFailTests = @()
if ($gettextVersion -le [Version]'0.22.5') {
    # see https://savannah.gnu.org/bugs/?66232
    $gettextXFailTests += 'msgexec-1 msgexec-3 msgexec-4 msgexec-5 msgexec-6 msgfilter-6 msgfilter-7 msginit-3'
}

class GnuUrlPrefixer
{
    [string[]] $_releaseUrlPrefixes = @(
        'https://ftpmirror.gnu.org',
        'https://ftp.halifax.rwth-aachen.de/gnu'
    )

    [string[]] $_alphaUrlPrefixes = @(
        'https://alpha.gnu.org/gnu',
        'https://gnualpha.uib.no'
    )

    [string] $_releaseUrlPrefix = ''
    [string] $_alphaUrlPrefix = ''

    [string] GetReleaseUrlPrefix()
    {
        if (-not($this._releaseUrlPrefix)) {
            $this._releaseUrlPrefix = $this._getUrlPrefix($this._releaseUrlPrefixes)
        }
        return $this._releaseUrlPrefix
    }

    [string] GetAlphaUrlPrefix()
    {
        if (-not($this._alphaUrlPrefix)) {
            $this._alphaUrlPrefix = $this._getUrlPrefix($this._alphaUrlPrefixes)
        }
        return $this._alphaUrlPrefix
    }

    [string] _getUrlPrefix([string[]] $prefixes)
    {
        foreach ($prefix in $prefixes) {
            try {
                $available = Invoke-WebRequest -Uri "$prefix/" -Method Head -ConnectionTimeoutSeconds 3 -OperationTimeoutSeconds 5 -ErrorAction SilentlyContinue
            } catch {
                $available = $false
            }
            if ($available) {
                return $prefix
            }
        }
        throw "None of these GNU URLs is available:`- $($prefixes -join "`\n- ")"
    }

    [void] WriteWarning()
    {
        $text = '';
        if ($this._releaseUrlPrefix -and $this._releaseUrlPrefix -ne $this._releaseUrlPrefixes[0]) {
            $text += "- stable: using $($this._releaseUrlPrefix) because $($this._releaseUrlPrefixes[0]) is not available`n"
        }
        if ($this._alphaUrlPrefix -and $this._alphaUrlPrefix -ne $this._alphaUrlPrefixes[0]) {
            $text += "- alpha: using $($this._alphaUrlPrefix) because $($this._alphaUrlPrefixes[0]) is not available`n"
        }
        if ($text -eq '') {
            return
        }
        Write-Host -Object @"
::warning ::Using GNU mirrors!
$text
See:
- https://www.gnu.org/prep/ftp.html
- https://web.archive.org/web/20240929102626/https://www.gnu.org/prep/ftp.html

"@
    }
}

$gnuUrlPrefixer = [GnuUrlPrefixer]::new()

$iconvSourceUrlPrefix = if ($env:ICONV_VERSION -match '^\d+(?:\.\d+)+(?:a|-pre\d+)$') {
    $gnuUrlPrefixer.GetAlphaUrlPrefix()
} else {
    $gnuUrlPrefixer.GetReleaseUrlPrefix()
}
$iconvSourceUrl = "$iconvSourceUrlPrefix/libiconv/libiconv-$env:ICONV_VERSION.tar.gz"

$gettextSourceUrlPrefix = if ($env:GETTEXT_VERSION -match '^\d+(?:\.\d+)+(?:a|-pre\d+)$') {
    $gnuUrlPrefixer.GetAlphaUrlPrefix()
} else {
    $gnuUrlPrefixer.GetReleaseUrlPrefix()
}
$gettextSourceUrl = "$gettextSourceUrlPrefix/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"

$gnuUrlPrefixer.WriteWarning()

$cygwinMirror = ''
foreach ($url in @(
    # The Linux Kernel Archives (North America / United States)
    'https://mirrors.kernel.org/sourceware/cygwin/',
    # University of Kent (Europe / UK)
    'https://www.mirrorservice.org/sites/sourceware.org/pub/cygwin/',
    # Oregon State University (North America / United States)
    'https://cygwin.osuosl.org/',
    # Manitoba UNIX User Group (North America / Canada)
    'https://muug.ca/mirror/cygwin/'
)) {
    try {
        $available = Invoke-WebRequest -Uri $url -Method Head -ConnectionTimeoutSeconds 3 -OperationTimeoutSeconds 5 -ErrorAction SilentlyContinue
    } catch {
        $available = $false
    }
    if ($available) {
        $cygwinMirror = $url
        break
    }
}
if (-not($cygwinMirror)) {
    throw 'Unable to reach any of the Cygwin mirrors'
}

$cldrPluralWorks = 'yes'
if ($Link -eq 'shared' -and $gettextVersion -lt [Version]'0.23') {
    # See https://savannah.gnu.org/bugs/?66356
    $cldrPluralWorks = 'no'
}

Export-Variable -Name 'cygwin-mirror' -Value $cygwinMirror
Export-Variable -Name 'cygwin-packages' -Value $($cygwinPackages -join ',')
Export-Variable -Name 'cygwin-path' -Value $($cygwinPath -join ':')
Export-Variable -Name 'mingw-host' -Value $mingwHost
Export-Variable -Name 'configure-args' -Value $($configureArgs -join ' ')
Export-Variable -Name 'configure-args-gettext' -Value $($gettextConfigureArgs -join ' ')
Export-Variable -Name 'iconv-source-url' -Value $iconvSourceUrl
Export-Variable -Name 'build-libcurl-version' -Value $buildLibcurlVersion
Export-Variable -Name 'build-libcurl-configure-args' -Value $($buildLibcurlConfigureArgs -join ' ')
Export-Variable -Name 'build-libcurl-curlconfig-arg' -Value $buildLibcurlCurlconfigArg
Export-Variable -Name 'build-json-c-version' -Value $buildJsonCVersion
Export-Variable -Name 'build-json-c-cmake-args' -Value $($buildJsonCCMakeArgs -join ' ')
Export-Variable -Name 'gettext-source-url' -Value $gettextSourceUrl
Export-Variable -Name 'gettext-ignore-tests-c' -Value $($gettextIgnoreTestsC -join ' ')
Export-Variable -Name 'gettext-xfail-gettext-tools' -Value $($gettextXFailTests -join ' ')
Export-Variable -Name 'signpath-signing-policy' -Value $signpathSigningPolicy
Export-Variable -Name 'signpath-artifactconfiguration-files' -Value $signpathArtifactConfigurationFiles
Export-Variable -Name 'signatures-canbeinvalid' -Value $signaturesCanBeInvalid
Export-Variable -Name 'cldr-plural-works' -Value $cldrPluralWorks
# See https://savannah.gnu.org/bugs/?func=detailitem&item_id=66378
Export-Variable -Name 'simplify-plurals-xml' -Value ($cldrMajorVersion -ge 38 ? 'true' : '')

Write-Output '## Outputs'
Get-Content -LiteralPath $env:GITHUB_OUTPUT
