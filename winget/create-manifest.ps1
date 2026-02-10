param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $PackageIdentifier,
    [Parameter(Mandatory = $true)]
    [psobject] $ReleaseData,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $ManifestsPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function New-InstallerEntry {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('x86', 'x64', 'arm', 'arm64', 'neutral')]
        [string] $Architecture,
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $AssetName
    )
    $asset = $ReleaseData.assets | Where-Object -Property 'name' -Value $AssetName -EQ
    if (-not $asset) {
        throw "Asset '$AssetName' not found in release '$($ReleaseData.tagName)'"
    }
    if ((-not $asset.digest) -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]+)$') {
        throw "Asset '$AssetName' does not have a valid sha256 digest in release '$($ReleaseData.tagName)'"
    }
    $sha256 = $matches[1]
    return [ordered]@{
        Architecture = $Architecture
        InstallerUrl = $asset.url
        InstallerSha256 = $sha256
    }
}

if ($ReleaseData.isPrerelease) {
    throw "Release '$($ReleaseData.tagName)' is a pre-release!"
}

$manifestVersion = '1.10.0'

if (-not($ReleaseData.tagName -match '^v(\d.+?)-v(\d.+?)(-r(\d+))?$')) {
    throw "Invalid tag name: $($ReleaseData.tagName)"
}
$gettextVersion = $matches[1]
$iconvVersion = $matches[2]
$revision = if ($matches[4]) { $matches[4] } else { $null }

$packageVersion = "$gettextVersion+$iconvVersion"
if ($null -ne $revision) {
    $packageVersion += "+r$revision"
}

# https://aka.ms/winget-manifest.version.1.10.0.schema.json
$version = [ordered]@{
    PackageIdentifier = $PackageIdentifier
    PackageVersion = $packageVersion
    DefaultLocale = 'en-US'
    ManifestType = 'version'
    ManifestVersion = $manifestVersion
}

# https://aka.ms/winget-manifest.defaultLocale.1.10.0.schema.json
$defaultLocale = [ordered]@{
    PackageIdentifier = $PackageIdentifier
    PackageVersion = $packageVersion
    PackageLocale = $version['DefaultLocale']
    Publisher = 'Michele Locati'
    PublisherUrl = 'https://github.com/mlocati/gettext-iconv-windows'
    PublisherSupportUrl = 'https://github.com/mlocati/gettext-iconv-windows/issues'
    Author = 'Michele Locati'
    PackageName = 'gettext + iconv'
    PackageUrl = 'https://mlocati.github.io/articles/gettext-iconv-windows.html'
    License = 'MIT'
    LicenseUrl = "https://github.com/mlocati/gettext-iconv-windows/blob/$($ReleaseData.tagName)/LICENSE.txt"
    Copyright = 'Copyright (c) Michele Locati'
    CopyrightUrl = "https://github.com/mlocati/gettext-iconv-windows/blob/$($ReleaseData.tagName)/LICENSE.txt"
    ShortDescription = 'gettext and iconv tools'
    Moniker = 'gettext'
    Tags = @(
        'GNU'
        'gettext'
        'iconv'
        'msgen'
        'msgfmt'
        'msginit'
        'msgmerge'
        'msgunfmt'
        'ngettext'
        'xgettext'
    )
    Agreements = @(
        [ordered]@{
            AgreementLabel = 'GNU gettext license'
            AgreementUrl = 'https://www.gnu.org/licenses/gpl-3.0.html'
        }
        [ordered]@{
            AgreementLabel = 'GNU iconv license'
            AgreementUrl = 'https://www.gnu.org/licenses/gpl-3.0.html'
        }
        [ordered]@{
            AgreementLabel = 'Unicode CLDR license'
            AgreementUrl = 'https://github.com/unicode-org/cldr/blob/HEAD/LICENSE'
        }
        [ordered]@{
            AgreementLabel = 'curl library license'
            AgreementUrl = 'https://curl.se/docs/copyright.html'
        }
        [ordered]@{
            AgreementLabel = 'JSON-C library license'
            AgreementUrl = 'https://github.com/json-c/json-c/blob/HEAD/COPYING'
        }
        [ordered]@{
            AgreementLabel = 'gcc runtime libraries license'
            AgreementUrl = 'https://gcc.gnu.org/onlinedocs/libstdc++/manual/license.html'
        }
    )
    ReleaseNotesUrl = $ReleaseData.url
    ManifestType = 'defaultLocale'
    ManifestVersion = $manifestVersion
}

# https://aka.ms/winget-manifest.installer.1.10.0.schema.json
$installer = [ordered]@{
    PackageIdentifier = $PackageIdentifier
    PackageVersion = $packageVersion
    InstallerLocale = 'en-US'
    MinimumOSVersion = '6.1.7601' # Windows 7
    InstallerType = 'inno'
    Scope = 'machine'
    UpgradeBehavior = 'install'
    ProductCode = 'gettext-iconv_is1'
    ReleaseDate = ([datetime]$ReleaseData.publishedAt).ToUniversalTime().ToString('yyyy\-MM\-dd')
    AppsAndFeaturesEntries = @(
        [ordered]@{
            ProductCode = 'gettext-iconv_is1'
        }
    )
    ElevationRequirement = 'elevatesSelf'
    InstallationMetadata = [ordered]@{
        DefaultInstallLocation = '%ProgramFiles%\gettext-iconv'
    }
    Installers = @(
        New-InstallerEntry -Architecture x86 -AssetName "gettext$gettextVersion-iconv$iconvVersion-shared-32.exe"
        New-InstallerEntry -Architecture x64 -AssetName "gettext$gettextVersion-iconv$iconvVersion-shared-64.exe"
    )
    ManifestType = 'installer'
    ManifestVersion = $manifestVersion
}

$manifestPath = $ManifestsPath
$childPaths = @([char]::ToLower($PackageIdentifier[0])) + ($PackageIdentifier -split '\.') + $packageVersion
$childPaths | ForEach-Object {
    $manifestPath = Join-Path -Path $manifestPath -ChildPath $_
}
if (Test-Path -LiteralPath $manifestPath -PathType Container) {
    Remove-Item -LiteralPath $manifestPath -Recurse -Force
}
New-Item -Path $manifestPath -ItemType Directory -Force | Out-Null

@("# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$manifestVersion.schema.json$([environment]::NewLine)") + (ConvertTo-Yaml $version) |
    Out-File -FilePath (Join-Path -Path $manifestPath -ChildPath "$PackageIdentifier.yaml") -Encoding UTF8 -NoNewline
@("# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.$manifestVersion.schema.json$([environment]::NewLine)") + (ConvertTo-Yaml $defaultLocale) |
    Out-File -FilePath (Join-Path -Path $manifestPath -ChildPath "$PackageIdentifier.locale.$($version['DefaultLocale']).yaml") -Encoding UTF8 -NoNewline
@("# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$manifestVersion.schema.json$([environment]::NewLine)") + (ConvertTo-Yaml $installer) |
    Out-File -FilePath (Join-Path -Path $manifestPath -ChildPath "$PackageIdentifier.installer.yaml") -Encoding UTF8 -NoNewline

$manifestPath, $packageVersion
