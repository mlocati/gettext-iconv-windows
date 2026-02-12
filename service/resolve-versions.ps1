param (
    [Parameter(Mandatory = $false)]
    [string] $CLDRVersion,
    [Parameter(Mandatory = $false)]
    [string] $IconvVersion,
    [Parameter(Mandatory = $false)]
    [string] $GettextVersion,
    [Parameter(Mandatory = $false)]
    [string] $CurlVersion,
    [Parameter(Mandatory = $false)]
    [string] $JsonCVersion,
    [Parameter(Mandatory = $false)]
    [ValidateSet('', 'no', 'test', 'production')]
    [string] $Sign,
    [Parameter(Mandatory = $true)]
    [bool] $PublishRelease,
    [Parameter(Mandatory = $false)]
    [Nullable[bool]] $Quick = $null
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/functions.ps1"

$script:pullRequestCommitMessages = $null

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
    if ($env:GITHUB_EVENT_NAME -ne 'pull_request') {
        return ''
    }
    $searchOptionNames = @(
        $OptionName
        ($OptionName -replace '-', '')
        ($OptionName -replace '-', ' ')
    )
    if ($null -eq $script:pullRequestCommitMessages) {
        $script:pullRequestCommitMessages = @()
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

function Get-BoolOptionFromPullRequestCommitMessages()
{
    [OutputType([Nullable[bool]])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $OptionName
    )
    $value = Get-OptionFromPullRequestCommitMessages -OptionName $OptionName
    if ($value -eq '') {
        return $null
    }
    if ($value -match '^(true|yes|y|on|1)$') {
        return $true
    }
    if ($value -match '^(false|no|n|off|0)$') {
        return $false
    }
    throw "Invalid boolean value for option '$OptionName': '$value'"
}

class GnuUrlPrefixer
{
    [string[]] $_releaseUrlPrefixes = @(
        'https://ftpmirror.gnu.org'
        'https://ftp.halifax.rwth-aachen.de/gnu'
    )

    [string[]] $_alphaUrlPrefixes = @(
        'https://alpha.gnu.org/gnu'
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
            if (Test-ServerAvailable -Url "$prefix/") {
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


# Process inputs

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
    $IconvVersion = '1.18'
}
$IconvVersionBase = $IconvVersion
$IconvTarballFromCommit = ''
$vo = ConvertTo-VersionObject $IconvVersion
if ((Compare-Versions $vo '1.18') -eq 0) {
    $IconvTarballFromCommit = '30fc26493e4c6457000172d49b526be0919e34c6'
}
if ($IconvTarballFromCommit) {
    $commitDate = Get-RemoteRepositoryCommitDate https://git.savannah.gnu.org/git/libiconv.git $IconvTarballFromCommit
    $IconvVersion = "$($vo.Major).$($vo.Minor).$($vo.Build).$commitDate"
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

if ((Compare-Versions $GettextVersion '1.0') -lt 0) {
    # Curl is not needed for gettext versions older than 1.0
    $CurlVersion = ''
} else {
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
}

if ((Compare-Versions $GettextVersion '1.0') -lt 0) {
    # JSON-C is not needed for gettext versions older than 1.0
    $JsonCVersion = ''
} else {
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
}

if ($Sign) {
    if ($Sign -ne 'no' -and $env:GITHUB_REPOSITORY -ne 'mlocati/gettext-iconv-windows') {
        Write-Host -Object "Using -Sign no instead of $Sign because the current repository ($($env:GITHUB_REPOSITORY)) is not the upstream one`n"
        $Sign = 'no'
    }
} else {
    if ($env:GITHUB_EVENT_NAME -eq 'pull_request') {
        $Sign = Get-OptionFromPullRequestCommitMessages -OptionName 'sign'
        if (-not $Sign) {
            $Sign = 'no'
        }
    } else {
        $Sign = 'test'
    }
}

if ($PublishRelease -and $Sign -ne 'production') {
    throw 'In order to publish a release, the -Sign argument must be set to "production".'
}
if ($null -eq $Quick) {
    $Quick = Get-BoolOptionFromPullRequestCommitMessages -OptionName 'quick'
    if ($null -eq $Quick) {
        $Quick = $false
    }
}
if ($Quick -and $PublishRelease) {
    throw 'The -Quick option cannot be used when publishing a release.'
}


# Determine source URLs

$isPrerelease = $false
$gnuUrlPrefixer = [GnuUrlPrefixer]::new()
if ($IconvVersion -match '^\d+(?:\.\d+)+(?:a|-pre\d+)$') {
    $iconvSourceUrlPrefix = $gnuUrlPrefixer.GetAlphaUrlPrefix()
    $isPrerelease = $true
} else {
    $iconvSourceUrlPrefix = $gnuUrlPrefixer.GetReleaseUrlPrefix()
}
$iconvSourceUrl = "$iconvSourceUrlPrefix/libiconv/libiconv-$IconvVersion.tar.gz"

if ($GettextVersion -match '^\d+(?:\.\d+)+(?:a|-pre\d+)$') {
    $gettextSourceUrlPrefix = $gnuUrlPrefixer.GetAlphaUrlPrefix()
    $isPrerelease = $true
} else {
    $gettextSourceUrlPrefix = $gnuUrlPrefixer.GetReleaseUrlPrefix()
}
$gettextSourceUrl = "$gettextSourceUrlPrefix/gettext/gettext-$GettextVersion.tar.gz"

$gnuUrlPrefixer.WriteWarning()

$cygwinMirror = ''
foreach ($url in @(
    # The Linux Kernel Archives (North America / United States)
    'https://mirrors.kernel.org/sourceware/cygwin/'
    # University of Kent (Europe / UK)
    'https://www.mirrorservice.org/sites/sourceware.org/pub/cygwin/'
    # Oregon State University (North America / United States)
    'https://cygwin.osuosl.org/'
    # Manitoba UNIX User Group (North America / Canada)
    'https://muug.ca/mirror/cygwin/'
)) {
    if (Test-ServerAvailable -Url $url) {
        $cygwinMirror = $url
        break
    }
}
if (-not($cygwinMirror)) {
    throw 'Unable to reach any of the Cygwin mirrors'
}


# Determine signing-related options

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
if ((Compare-Versions $GettextVersion '1.0') -ge 0) {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-1.0'
} elseif ((Compare-Versions $GettextVersion '0.23') -ge 0) {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-0.23'
} else {
    $signpathArtifactConfigurationFiles = 'gh_sign_files-0.22'
}


# Determine tag of the release to be published (if any)
$releaseTag = ''
if ($PublishRelease) {
    $rawTags = git ls-remote --tags origin
    if (-not ($?)) {
        throw 'Unable to get the list of tags from the origin remote'
    }
    $tags = $rawTags | ForEach-Object { $_.Split('refs/tags/')[1] }
    $releaseTagBase = "v$GettextVersion-v$IconvVersionBase"
    if (-not($tags -contains $releaseTagBase)) {
        $releaseTag = $releaseTagBase
    } else {
        for ($r = 1; ; $r++) {
            $releaseTag = "$releaseTagBase-r$r"
            if (-not($tags -contains $releaseTag)) {
                break
            }
        }
    }
}

# Export variables

Add-GithubOutput -Name 'cygwin-mirror' -Value $cygwinMirror
Add-GithubOutput -Name 'cldr-version' -Value $CLDRVersion
Add-GithubOutput -Name 'iconv-version' -Value $IconvVersion
Add-GithubOutput -Name 'iconv-version-base' -Value $IconvVersionBase
Add-GithubOutput -Name 'iconv-tarball-from-commit' -Value $IconvTarballFromCommit
Add-GithubOutput -Name 'iconv-source-url' -Value $iconvSourceUrl
Add-GithubOutput -Name 'curl-version' -Value $CurlVersion
Add-GithubOutput -Name 'json-c-version' -Value $JsonCVersion
Add-GithubOutput -Name 'gettext-version' -Value $GettextVersion
Add-GithubOutput -Name 'gettext-source-url' -Value $gettextSourceUrl
Add-GithubOutput -Name 'signpath-signing-policy' -Value $signpathSigningPolicy
Add-GithubOutput -Name 'signpath-artifactconfiguration-files' -Value $signpathArtifactConfigurationFiles
Add-GithubOutput -Name 'signatures-canbeinvalid' -Value $(if ($signaturesCanBeInvalid) { 'yes' } else { 'no' })
Add-GithubOutput -Name 'release-tag' -Value $releaseTag
Add-GithubOutput -Name 'is-prerelease' -Value $(if ($isPrerelease) { 'yes' } else { 'no' })
Add-GithubOutput -Name 'quick' -Value $(if ($Quick) { 'yes' } else { 'no' })

Write-Output '## Outputs'
Get-GitHubOutputs
