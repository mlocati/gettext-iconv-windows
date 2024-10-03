# Script that sets some variables used in the GitHub Action steps

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $Bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $Link,
    [Parameter(Mandatory = $false)]
    [ValidateSet('', 'no', 'test', 'production')]
    [string] $Sign
)

if (-not($env:ICONV_VERSION)) {
    throw 'Missing ICONV_VERSION environment variable'
}
if (-not($env:GETTEXT_VERSION)) {
    throw 'Missing GETTEXT_VERSION environment variable'
}
$gettextVersionNumeric = $env:GETTEXT_VERSION -replace '[a-z]+$',''
$gettextVersionObject = [Version]$gettextVersionNumeric

switch ($Bits) {
    32 {
        $architecture = 'i686'
    }
    64 {
        $architecture = 'x86_64'
    }
}

$cygwinPackages = "file,make,unzip,perl,mingw64-$architecture-gcc-core,mingw64-$architecture-gcc-g++,mingw64-$architecture-headers,mingw64-$architecture-runtime"

$mingwHost = "$architecture-w64-mingw32"

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

"cygwin-packages=$cygwinPackages" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"cygwin-path=/usr/$mingwHost/bin:/usr/$mingwHost/sys-root/mingw/bin:/usr/sbin:/usr/bin:/sbin:/bin:/cygdrive/c/Windows/System32:/cygdrive/c/Windows" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"mingw-host=$mingwHost" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"configure-args=$configureArgs" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"cpp-flags=-I/usr/$mingwHost/sys-root/mingw/include -g0 -O2" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"ld-flags=-L/usr/$mingwHost/sys-root/mingw/lib" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"cxx-flags=-fno-threadsafe-statics" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"iconv-source-url=$iconvSourceUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-source-url=$gettextSourceUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-ignore-tests-c=$gettextIgnoreTestsC" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-xfail-gettext-tools=$gettextXFailTests" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"signpath-signing-policy=$signpathSigningPolicy" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"signatures-canbeinvalid=$signaturesCanBeInvalid" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
"gettext-peversion-numeric=$gettextVersionNumeric" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8

Write-Output '## Outputs'
Get-Content -LiteralPath $env:GITHUB_OUTPUT
