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

function Resolve-TPVersion()
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [Version] $Version,
        [Parameter(Mandatory = $true)]
        [string[]] $TPVersions
    )
    $sortedTPVersions = $TPVersions | Sort-Object -Property { ConvertTo-Version  -Version $_ } -Descending
    foreach ($tpVersion in $sortedTPVersions) {
        $cmp = ConvertTo-Version -Version $tpVersion
        if ($Version -ge $cmp) {
            if ($tpVersion -eq $sortedTPVersions[0]) {
                return 'latest'
            }
            return $tpVersion
        }
    }
    return $sortedTPVersions[-1]
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
$iconvVersion = ConvertTo-Version -Version $env:ICONV_VERSION
$iconvTPVersion = Resolve-TPVersion -Version $iconvVersion -TPVersions @(
    '1.12',
    '1.15-pre1',
    '1.17-pre1'
)

if (-not($env:GETTEXT_VERSION)) {
    throw 'Missing GETTEXT_VERSION environment variable'
}
$gettextVersion = ConvertTo-Version -Version $env:GETTEXT_VERSION
$gettextTPVersion = Resolve-TPVersion -Version $gettextVersion -TPVersions @(
    '0.10.35',
    '0.10.38',
    '0.10.39',
    '0.11.2',
    '0.11.5',
    '0.12-pre1',
    '0.12.1',
    '0.13-pre1',
    '0.13.1',
    '0.14',
    '0.14.5',
    '0.15-pre5',
    '0.16',
    '0.16.2-pre5',
    '0.17',
    '0.18',
    '0.18.2',
    '0.18.3',
    '0.19-rc1',
    '0.19.3',
    '0.19.4-rc1',
    '0.19.4.73',
    '0.19.6.43',
    '0.19.7-rc1',
    '0.19.8-rc1',
    '0.20-rc1',
    '0.20.2',
    '0.21',
    '0.22',
    '0.23-pre1'
)
$gettextPENameLibGettextLib = 'GNU gettext utilities'
$gettextPEVersionLibGettextLib = $env:GETTEXT_VERSION
$gettextPENameLibGettextSrc = 'GNU gettext utilities'
$gettextPEVersionLibGettextSrc = $env:GETTEXT_VERSION
$gettextPEVersionLibIntl = $env:GETTEXT_VERSION
$gettextPEVersionLibTextStyle = $env:GETTEXT_VERSION
if ($gettextVersion -le [Version]'0.22.5') {
    $gettextPENameLibGettextLib = ''
    $gettextPEVersionLibGettextLib = ''
    $gettextPENameLibGettextSrc = ''
    $gettextPEVersionLibGettextSrc = ''
}
switch ($env:GETTEXT_VERSION) {
    0.22.5a {
        $gettextPEVersionLibIntl = '0.22.5'
        $gettextPEVersionLibTextStyle = '0.22.5'
    }
    0.23-pre1 {
        $gettextPEVersionLibTextStyle = '0.22.5'
    }
}

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

# We use -fno-threadsafe-statics because:
# - otherwise xgettext would use the the __cxa_guard_acquire and __cxa_guard_release functions of lib-stdc++
# - the only tool that uses multi-threading is msgmerge, which is in C (and not C++)
# See:
# - https://sourceforge.net/p/mingw-w64/mailman/message/58824383/
# - https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00008.html
# - https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00010.html
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
    "CPPFLAGS='-I$cygwinInstalledPath/include -I/usr/$mingwHost/sys-root/mingw/include -g0 -O2'",
    # The flags for the C compiler
    "CFLAGS=''",
    # The flags for the C++ compiler
    "CXXFLAGS='-fno-threadsafe-statics'",
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
    if (-not($dotnetCommand) || -not($dotnetCommand.Path)) {
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
switch ($env:ICONV_VERSION) {
    default {
        $iconvSourceUrl = "$($gnuUrlPrefixer.GetReleaseUrlPrefix())/libiconv/libiconv-$env:ICONV_VERSION.tar.gz"
    }
}

switch ($env:GETTEXT_VERSION) {
    '0.22.5a' {
        # see https://lists.gnu.org/archive/html/bug-gettext/2024-09/msg00039.html
        $gettextSourceUrl = "$($gnuUrlPrefixer.GetAlphaUrlPrefix())/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"
    }
    '0.23-pre1' {
        # see https://lists.gnu.org/archive/html/bug-gettext/2024-09/msg00039.html
        $gettextSourceUrl = "$($gnuUrlPrefixer.GetAlphaUrlPrefix())/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"
    }
    default {
        $gettextSourceUrl = "$($gnuUrlPrefixer.GetReleaseUrlPrefix())/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"
    }
}
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

Export-Variable -Name 'cygwin-mirror' -Value $cygwinMirror
Export-Variable -Name 'cygwin-packages' -Value "wget,file,make,unzip,dos2unix,mingw64-$architecture-gcc-core,mingw64-$architecture-gcc-g++,mingw64-$architecture-headers,mingw64-$architecture-runtime"
Export-Variable -Name 'cygwin-path' -Value $($cygwinPath -join ':')
Export-Variable -Name 'mingw-host' -Value $mingwHost
Export-Variable -Name 'configure-args' -Value $($configureArgs -join ' ')
Export-Variable -Name 'configure-args-gettext' -Value $($gettextConfigureArgs -join ' ')
Export-Variable -Name 'iconv-source-url' -Value $iconvSourceUrl
Export-Variable -Name 'gettext-source-url' -Value $gettextSourceUrl
Export-Variable -Name 'gettext-ignore-tests-c' -Value $($gettextIgnoreTestsC -join ' ')
Export-Variable -Name 'gettext-xfail-gettext-tools' -Value $($gettextXFailTests -join ' ')
Export-Variable -Name 'signpath-signing-policy' -Value $signpathSigningPolicy
Export-Variable -Name 'signpath-artifactconfiguration-files' -Value $signpathArtifactConfigurationFiles
Export-Variable -Name 'signatures-canbeinvalid' -Value $signaturesCanBeInvalid
Export-Variable -Name 'gettext-pename-libgettextlib' -Value $gettextPENameLibGettextLib
Export-Variable -Name 'gettext-peversion-libgettextlib' -Value $gettextPEVersionLibGettextLib
Export-Variable -Name 'gettext-pename-libgettextsrc' -Value $gettextPENameLibGettextSrc
Export-Variable -Name 'gettext-peversion-libgettextsrc' -Value $gettextPEVersionLibGettextSrc
Export-Variable -Name 'gettext-peversion-libintl' -Value $gettextPEVersionLibIntl
Export-Variable -Name 'gettext-peversion-libtextstyle' -Value $gettextPEVersionLibTextStyle
Export-Variable -Name 'iconv-tp-version' -Value $iconvTPVersion
Export-Variable -Name 'gettext-tp-version' -Value $gettextTPVersion

Write-Output '## Outputs'
Get-Content -LiteralPath $env:GITHUB_OUTPUT
