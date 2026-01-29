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
    [string] $Sign,
    [Parameter(Mandatory = $false)]
    [string] $CLDRVersion,
    [Parameter(Mandatory = $false)]
    [string] $IconvVersion,
    [Parameter(Mandatory = $false)]
    [string] $GettextVersion,
    [Parameter(Mandatory = $false)]
    [string] $CurlVersion,
    [Parameter(Mandatory = $false)]
    [string] $JsonCVersion
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

function Get-OptionFromPullRequestCommitMessages()
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $OptionName
    )
    if (-not($OptionName -match '^[A-Za-z0-9\-_]+$')) {
        throw "Invalid OptionName: '$OptionName'"
    }
    $searchOptionNames = @(
        $OptionName,
        ($OptionName -replace '-', ''),
        ($OptionName -replace '-', ' ')
    )
    if (-not $script:pullRequestCommitMessages) {
        $script:pullRequestCommitMessages = @()
        if ($env:GITHUB_EVENT_NAME -eq 'pull_request') {
            if (-not(Test-Path -LiteralPath $env:GITHUB_WORKSPACE -PathType Container)) {
                throw "The GitHub Action path '$env:GITHUB_WORKSPACE' does not exist"
            }
            $baseRef = $env:GITHUB_BASE_REF
            $headRef = $env:GITHUB_HEAD_REF
            if (-not $baseRef -or -not $headRef) {
                throw "Invalid GitHub Action refs: base='$baseRef', head='$headRef'"
            }
            $mergeBase = git -C "$env:GITHUB_WORKSPACE" merge-base "origin/$baseRef" "origin/$headRef"
            if (-not $mergeBase) {
                throw "Unable to find the merge base between 'origin/$baseRef' and 'origin/$headRef'"
            }
            $script:pullRequestCommitMessages = git -C "$env:GITHUB_WORKSPACE" log "$mergeBase..origin/$headRef" --pretty=format:'%s%n%b%n'
            if (-not $script:pullRequestCommitMessages) {
                throw "Unable to get the commit messages between '$mergeBase' and 'origin/$headRef'"
            }
        }
    }
    foreach ($message in $script:pullRequestCommitMessages) {
        foreach ($searchOptionName in $searchOptionNames) {
            $match = Select-String -InputObject $message -Pattern "^\s*\/$searchOptionName(\s+|\s*:\s*|\s*=\s*)([^\s]+)\s*$"
            if ($match) {
                return $match.Matches.Groups[2].Value
            }
            if ($message -match "^\s*\/$searchOptionName[\s:=]*$") {
                return ''
            }
        }
    }
    return ''
}

if ($CLDRVersion) {
    $CLDRVersion = $CLDRVersion.Trim()
} else {
    $CLDRVersion = Get-OptionFromPullRequestCommitMessages -OptionName 'cldr-version'
}
if ($CLDRVersion) {
    if (-not($CLDRVersion -match '^\d+(\.\d+)?[a-z0-9_\-.]*$')) {
        throw "Invalid CLDRVersion: '$CLDRVersion'"
    }
} else {
    $CLDRVersion = '48.1'
}
if ($IconvVersion) {
    $IconvVersion = $IconvVersion.Trim()
} else {
    $IconvVersion = Get-OptionFromPullRequestCommitMessages -OptionName 'iconv-version'
}
if ($IconvVersion) {
    if (-not($IconvVersion -match '^\d+\.\d+?[a-z0-9_\-.]*$')) {
        throw "Invalid iconv version: '$IconvVersion'"
    }
} else {
    $IconvVersion = '1.17'
}
if ($GettextVersion) {
    $GettextVersion = $GettextVersion.Trim()
} else {
    $GettextVersion = Get-OptionFromPullRequestCommitMessages -OptionName 'gettext-version'
}
if ($GettextVersion) {
    if (-not($GettextVersion -match '^\d+\.\d+?[a-z0-9_\-.]*$')) {
        throw "Invalid gettext version: '$GettextVersion'"
    }
} else {
    $GettextVersion = '1.0'
}
if ($CurlVersion) {
    $CurlVersion = $CurlVersion.Trim()
} else {
    $CurlVersion = Get-OptionFromPullRequestCommitMessages -OptionName 'curl-version'
}
if ($CurlVersion) {
    if (-not($CurlVersion -match '^\d+\.\d+?[a-z0-9_\-.]*$')) {
        throw "Invalid curl version: '$CurlVersion'"
    }
} else {
    $CurlVersion = '8.18.0'
}
if ($JsonCVersion) {
    $JsonCVersion = $JsonCVersion.Trim()
} else {
    $JsonCVersion = Get-OptionFromPullRequestCommitMessages -OptionName 'json-c-version'
}
if ($JsonCVersion) {
    if (-not($JsonCVersion -match '^\d+\.\d+?[a-z0-9_\-.]*$')) {
        throw "Invalid JSON-C version: '$JsonCVersion'"
    }
} else {
    $JsonCVersion = '0.18'
}

$cldrMajorVersion = [int][regex]::Match($CLDRVersion, '^\d+').Value

$gettextVersionObject = ConvertTo-Version -Version $GettextVersion

$simplifyPluralsXml = $cldrMajorVersion -ge 38 -and $gettextVersionObject -lt [Version]'1.0'

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

if ($Bits -eq 32 -and $Link -eq 'shared') {
    $ldFlags = '-static-libgcc'
} else {
    $ldFlags = ''
}

$mingwHost = "$architecture-w64-mingw32"
$gccRuntimeLicense = "/usr/share/doc/mingw64-$architecture-gcc/COPYING"

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
$cxxFlags = '-g0 -O2 -fno-exceptions -fno-rtti'

$buildLibcurlConfigureArgs = @()
$buildJsonCCMakeArgs = @()
$checkSpitExe = $false

if ($gettextVersionObject -ge [Version]'1.0') {
    # The spit program (introduced in gettext 1.0) requires libcurl and json-c (otherwise gettext builds a Python script)
    $checkSpitExe = $true
    $cygwinPackages += 'cmake'
    $buildLibcurlConfigureArgs = @(
        "CC='$mingwHost-gcc'",
        "CXX='$mingwHost-g++'",
        "LD='$mingwHost-ld'",
        "STRIP='$mingwHost-strip'",
        "CPPFLAGS='-I$cygwinInstalledPath/include -I/usr/$mingwHost/sys-root/mingw/include -DWINVER=0x0601 -D_WIN32_WINNT=0x0601'",
        "CFLAGS='-g0 -O2'",
        "CXXFLAGS='-g0 -O2 -fno-exceptions -fno-rtti'",
        "LDFLAGS='-L$cygwinInstalledPath/lib -L/usr/$mingwHost/sys-root/mingw/lib $ldFlags'",
        "--host=$mingwHost",
        '--enable-http',
        '--disable-file',
        '--disable-ftp',
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
        '--disable-websockets',
        '--disable-manual',
        '--disable-docs',
        '--enable-ipv6',
        '--enable-windows-unicode',
        '--disable-cookies',
        '--with-schannel',
        '--without-gnutls',
        '--without-openssl',
        '--without-rustls',
        '--without-wolfssl',
        '--without-libpsl',
        '--with-winidn',
        '--disable-threaded-resolver',
        '--disable-kerberos-auth',
        '--disable-ntlm',
        '--disable-negotiate-auth',
        '--disable-sspi',
        '--disable-unix-sockets',
        '--disable-dependency-tracking',
        "--prefix=$cygwinInstalledPath"
    )
    $buildJsonCCMakeArgs = @(
        '-DCMAKE_BUILD_TYPE=Release',
        "'-DCMAKE_INSTALL_PREFIX=$cygwinInstalledPath'",
        '-DCMAKE_POLICY_VERSION_MINIMUM=3.5',
        '-DBUILD_TESTING=OFF',
        "-DCMAKE_C_COMPILER=$mingwHost-gcc",
        "-DCMAKE_C_FLAGS='-g0 -O2'",
        '-DDISABLE_THREAD_LOCAL_STORAGE=ON',
        '-DENABLE_THREADING=OFF',
        '-DBUILD_APPS=OFF',
        '-DCMAKE_SYSTEM_NAME=Windows',
        "-DCMAKE_CXX_FLAGS='-fno-exceptions -fno-rtti'",
        "-DCMAKE_SHARED_LINKER_FLAGS='$ldFlags'"
    )
    switch ($Link) {
        'shared' {
            $buildLibcurlConfigureArgs += '--enable-shared'
            $buildLibcurlConfigureArgs += '--disable-static'
            $buildJsonCCMakeArgs += '-DBUILD_SHARED_LIBS=ON'
            $buildJsonCCMakeArgs += '-DBUILD_STATIC_LIBS=OFF'
        }
        'static' {
            $cFlags = "$cFlags -DCURL_STATICLIB"
            $buildLibcurlConfigureArgs += '--enable-static'
            $buildLibcurlConfigureArgs += '--disable-shared'
            $buildJsonCCMakeArgs += '-DBUILD_STATIC_LIBS=ON'
            $buildJsonCCMakeArgs += '-DBUILD_SHARED_LIBS=OFF'
        }
    }
} else {
    $CurlVersion = ''
    $JsonCVersion = ''
}

if ($gettextVersionObject -lt [Version]'0.26' -or $GettextVersion -eq '0.26-pre1') {
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
    "LDFLAGS='-L$cygwinInstalledPath/lib -L/usr/$mingwHost/sys-root/mingw/lib $ldFlags'",
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
if ($gettextVersionObject -le [Version]'0.22.5') {
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
} elseif (-not $Sign) {
    if ($env:GITHUB_EVENT_NAME -eq 'pull_request') {
        $Sign = Get-OptionFromPullRequestCommitMessages -OptionName 'sign'
        if (-not $Sign) {
            $Sign = 'no'
        }
    } else {
        $Sign = 'test'
    }
}

$signpathSigningPolicy = ''
$signaturesCanBeInvalid = $false
switch ($Sign) {
    'no' {
    }
    'test' {
        $signpathSigningPolicy = 'test-signing'
        $signaturesCanBeInvalid = $true
    }
    'production' {
        $signpathSigningPolicy = 'release-signing'
    }
    default {
        throw "Invalid value of the -Sign argument ($Sign)"
    }
}

if ($gettextVersionObject -le [Version]'0.22.5') {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-0.22'
} elseif ($gettextVersionObject -le [Version]'0.99.99') {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-0.23'
} else {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-1.0'
}

$gettextIgnoreTestsC = @()
# see https://lists.gnu.org/archive/html/bug-gnulib/2024-09/msg00137.html
$gettextIgnoreTestsC += 'gettext-tools/gnulib-tests/test-asyncsafe-spin2.c'
if ($gettextVersionObject -le [Version]'0.22.5') {
    # see https://lists.gnu.org/archive/html/bug-gnulib/2024-09/msg00137.html
    $gettextIgnoreTestsC += 'gettext-tools/gnulib-tests/test-getopt-gnu.c gettext-tools/gnulib-tests/test-getopt-posix.c'
}

$gettextXFailTests = @()
if ($gettextVersionObject -le [Version]'0.22.5') {
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

$iconvSourceUrlPrefix = if ($IconvVersion -match '^\d+(?:\.\d+)+(?:a|-pre\d+)$') {
    $gnuUrlPrefixer.GetAlphaUrlPrefix()
} else {
    $gnuUrlPrefixer.GetReleaseUrlPrefix()
}
$iconvSourceUrl = "$iconvSourceUrlPrefix/libiconv/libiconv-$IconvVersion.tar.gz"

$gettextSourceUrlPrefix = if ($GettextVersion -match '^\d+(?:\.\d+)+(?:a|-pre\d+)$') {
    $gnuUrlPrefixer.GetAlphaUrlPrefix()
} else {
    $gnuUrlPrefixer.GetReleaseUrlPrefix()
}
$gettextSourceUrl = "$gettextSourceUrlPrefix/gettext/gettext-$GettextVersion.tar.gz"

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
if ($Link -eq 'shared' -and $gettextVersionObject -lt [Version]'0.23') {
    # See https://savannah.gnu.org/bugs/?66356
    $cldrPluralWorks = 'no'
}

Export-Variable -Name 'cldr-version' -Value $CLDRVersion
Export-Variable -Name 'iconv-version' -Value $IconvVersion
Export-Variable -Name 'gettext-version' -Value $GettextVersion
Export-Variable -Name 'curl-version' -Value $CurlVersion
Export-Variable -Name 'json-c-version' -Value $JsonCVersion
Export-Variable -Name 'cygwin-mirror' -Value $cygwinMirror
Export-Variable -Name 'cygwin-packages' -Value $($cygwinPackages -join ',')
Export-Variable -Name 'cygwin-path' -Value $($cygwinPath -join ':')
Export-Variable -Name 'mingw-host' -Value $mingwHost
Export-Variable -Name 'gcc-runtime-license' -Value $gccRuntimeLicense
Export-Variable -Name 'configure-args' -Value $($configureArgs -join ' ')
Export-Variable -Name 'configure-args-gettext' -Value $($gettextConfigureArgs -join ' ')
Export-Variable -Name 'iconv-source-url' -Value $iconvSourceUrl
Export-Variable -Name 'build-libcurl-configure-args' -Value $($buildLibcurlConfigureArgs -join ' ')
Export-Variable -Name 'build-json-c-cmake-args' -Value $($buildJsonCCMakeArgs -join ' ')
Export-Variable -Name 'gettext-source-url' -Value $gettextSourceUrl
Export-Variable -Name 'gettext-ignore-tests-c' -Value $($gettextIgnoreTestsC -join ' ')
Export-Variable -Name 'gettext-xfail-gettext-tools' -Value $($gettextXFailTests -join ' ')
Export-Variable -Name 'signpath-signing-policy' -Value $signpathSigningPolicy
Export-Variable -Name 'signpath-artifactconfiguration-files' -Value $signpathArtifactConfigurationFiles
Export-Variable -Name 'signatures-canbeinvalid' -Value $(if ($signaturesCanBeInvalid) { '1' } else { '0' })
Export-Variable -Name 'cldr-plural-works' -Value $cldrPluralWorks
# See https://savannah.gnu.org/bugs/?func=detailitem&item_id=66378
Export-Variable -Name 'simplify-plurals-xml' -Value $(if ($simplifyPluralsXml) { 'yes' } else { 'no' })
Export-Variable -Name 'check-spit-exe' -Value $(if ($checkSpitExe) { 'yes' } else { 'no' })

Write-Output '## Outputs'
Get-Content -LiteralPath $env:GITHUB_OUTPUT
