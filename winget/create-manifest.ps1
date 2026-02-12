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

function Get-ReleaseNotes {
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $ReleaseData
    )
    $body = $ReleaseData.body.Trim()
    $body = ($body -replace '\r\n',"`n") -replace '\r',"`n"
    $body = $body -replace '(?ms)\s*<!--\s*virustotal\s*-->.*?<!--\s*/virustotal\s*-->\s*',"`n"

    return $body -replace '\n',[environment]::NewLine
}

function New-InstallerEntry {
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('x86', 'x64', 'arm', 'arm64', 'neutral')]
        [string] $Architecture,
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $AssetName,
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $DisplayName
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
        AppsAndFeaturesEntries = @(
            [ordered]@{
                DisplayName = $DisplayName
                ProductCode = 'gettext-iconv_is1'
            }
        )
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
    ShortDescription = 'GNU gettext and GNU iconv tools'
    Description = @'
This package provides the GNU gettext and GNU iconv tools for Windows, which are used for internationalization and localization of software applications.

The GNU gettext tools include the following command-line utilities used for managing translation files and generating localized resources:

- gettext: display native language translation of a textual message
- msgattrib: filters the messages of a translation catalog according to their attributes, and manipulates the attributes
- msgcat: concatenates and merges the specified PO files
- msgcmp: compare two Uniforum style .po files to check that both contain the same set of msgid strings
- msgcomm: find messages which are common to two or more of the specified PO files
- msgconv: convert a translation catalog to a different character encoding
- msgen: create an English translation catalog
- msgexec: apply a command to all translations of a translation catalog
- msgfilter: apply a filter to all translations of a translation catalog
- msgfmt: generate binary message catalog from textual translation description.
- msggrep: extract all messages of a translation catalog that match a given pattern or belong to some given source files
- msginit: create a new PO file, initializing the meta information with values from the user's environment
- msgmerge: merge two Uniforum style .po files together
- msgpre: pretranslate a translation catalog
- msgunfmt: convert a binary message catalog to Uniforum style .po file
- msguniq: unify duplicate translations in a translation catalog
- ngettext: display native language translation of a textual message whose grammatical form depends on a number
- recode-sr-latin: recode Serbian text from Cyrillic to Latin script
- spit: pass standard input to a Large Language Model (LLM) instance and prints the response
- xgettext: extract translatable strings from given input files

The GNU iconv tool is used for converting text between different character encodings.

The package comes with Unicode CLDR data, which is used by msginit to create translation catalogs with the plural rules defined in CLDR (this requires setting the GETTEXTCLDRDIR environment variable to the path of the CLDR data).
'@
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
    ReleaseNotes = Get-ReleaseNotes -ReleaseData $ReleaseData
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
    InstallModes = @(
        'interactive'
        'silent'
        'silentWithProgress'
    )
    UpgradeBehavior = 'install'
    ProductCode = 'gettext-iconv_is1'
    ReleaseDate = ([datetime]$ReleaseData.publishedAt).ToUniversalTime().ToString('yyyy\-MM\-dd')
    ElevationRequirement = 'elevatesSelf'
    InstallationMetadata = [ordered]@{
        DefaultInstallLocation = '%ProgramFiles%\gettext-iconv'
    }
    Installers = @(
        New-InstallerEntry -Architecture x86 -AssetName "gettext$gettextVersion-iconv$iconvVersion-shared-32.exe" -DisplayName "gettext $gettextVersion + iconv $iconvVersion - shared (32 bit)"
        New-InstallerEntry -Architecture x64 -AssetName "gettext$gettextVersion-iconv$iconvVersion-shared-64.exe" -DisplayName "gettext $gettextVersion + iconv $iconvVersion - shared (64 bit)"
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
    $versionOperation = 'updated'
} else {
    $versionOperation = 'created'
}
New-Item -Path $manifestPath -ItemType Directory -Force | Out-Null

@("# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$manifestVersion.schema.json$([environment]::NewLine)") + (ConvertTo-Yaml $version ) |
    Out-File -FilePath (Join-Path -Path $manifestPath -ChildPath "$PackageIdentifier.yaml") -Encoding UTF8 -NoNewline
@("# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.$manifestVersion.schema.json$([environment]::NewLine)") + (ConvertTo-Yaml $defaultLocale ) |
    Out-File -FilePath (Join-Path -Path $manifestPath -ChildPath "$PackageIdentifier.locale.$($version['DefaultLocale']).yaml") -Encoding UTF8 -NoNewline
@("# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$manifestVersion.schema.json$([environment]::NewLine)") + (ConvertTo-Yaml $installer ) |
    Out-File -FilePath (Join-Path -Path $manifestPath -ChildPath "$PackageIdentifier.installer.yaml") -Encoding UTF8 -NoNewline

$manifestPath, $packageVersion, $versionOperation
