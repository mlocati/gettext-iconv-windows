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

if (-not($env:ICONV_VERSION)) {
    throw 'Missing ICONV_VERSION environment variable'
}
if (-not($env:GETTEXT_VERSION)) {
    throw 'Missing GETTEXT_VERSION environment variable'
}
$gettextVersionNumeric = $env:GETTEXT_VERSION -replace '[a-z]+$',''
$gettextVersionObject = [Version]$gettextVersionNumeric

$absoluteInstalledPath = [System.IO.Path]::Combine($(Get-Location), $InstalledPath)
$match = Select-String -InputObject $absoluteInstalledPath -Pattern '^([A-Za-z]):(\\.*?)\\?$'
if (!$match) {
    throw "Invalid value of InstalledPath '$InstalledPath' (resolved to '$absoluteInstalledPath')"
}
$cygwinInstalledPath = '/cygdrive/' + $match.Matches.Groups[1].Value.ToLowerInvariant() + $match.Matches.Groups[2].Value.Replace('\', '/')

switch ($Bits) {
    32 {
        $architecture = 'i686'
    }
    64 {
        $architecture = 'x86_64'
    }
}

$mingwHost = "$architecture-w64-mingw32"

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
        $signaturesCanBeInvalid = 1
        Write-Host "SignPath signing policy: $signpathSigningPolicy (production certificate)`n"
    }
    default {
        throw "Invalid value of the -Sign argument ($Sign)"
    }
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
    default {
        $gettextSourceUrl = "$($gnuUrlPrefixer.GetReleaseUrlPrefix())/gettext/gettext-$env:GETTEXT_VERSION.tar.gz"
    }
}
$gnuUrlPrefixer.WriteWarning()

Export-Variable -Name 'cygwin-packages' -Value "file,make,unzip,dos2unix,mingw64-$architecture-gcc-core,mingw64-$architecture-gcc-g++,mingw64-$architecture-headers,mingw64-$architecture-runtime"
Export-Variable -Name 'cygwin-path' -Value "$cygwinInstalledPath/bin:/usr/$mingwHost/bin:/usr/$mingwHost/sys-root/mingw/bin:/usr/sbin:/usr/bin:/sbin:/bin:/cygdrive/c/Windows/System32:/cygdrive/c/Windows"
Export-Variable -Name 'mingw-host' -Value $mingwHost
Export-Variable -Name 'configure-args' -Value $($configureArgs -join ' ')
Export-Variable -Name 'iconv-source-url' -Value $iconvSourceUrl
Export-Variable -Name 'gettext-source-url' -Value $gettextSourceUrl
Export-Variable -Name 'gettext-ignore-tests-c' -Value $($gettextIgnoreTestsC -join ' ')
Export-Variable -Name 'gettext-xfail-gettext-tools' -Value $($gettextXFailTests -join ' ')
Export-Variable -Name 'signpath-signing-policy' -Value $signpathSigningPolicy
Export-Variable -Name 'signatures-canbeinvalid' -Value $signaturesCanBeInvalid
Export-Variable -Name 'gettext-peversion-numeric' -Value $gettextVersionNumeric

Write-Output '## Outputs'
Get-Content -LiteralPath $env:GITHUB_OUTPUT
