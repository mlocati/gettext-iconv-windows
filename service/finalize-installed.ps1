[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'Link', Justification = 'Unused at the moment, but may be used in the future')]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $Bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $Link,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $Path,
    [Parameter(Mandatory = $false)]
    [string] $MinGWPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/functions.ps1"

function Add-LicenseText()
{
    param (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Text
    )
    $licenseFilePath = Join-Path -Path $Path -ChildPath 'license.txt'
    $Text.TrimEnd() + "`n" | Out-File -FilePath $licenseFilePath -Encoding UTF8 -Append -NoNewline
}

$binaries = [BinaryFileCollection]::new($Bits, $Path)

if ($MinGWPath) {
  $mingwBinPath = Join-Path -Path $MinGWPath -ChildPath 'sys-root\mingw\bin'
  $binaries.AddMingwDlls($mingwBinPath)
}

$binaries.Dump()

if ($MinGWPath) {
  Add-LicenseText @'


This project was compiled using the mingw-w64 ( https://www.mingw-w64.org/ ) toolchain
under the Cygwin environment ( https://www.cygwin.com/ ).
'@
} else {
  Add-LicenseText @'


This project was compiled under the Cygwin environment ( https://www.cygwin.com/ ).
'@
}

Add-LicenseText @'

This project includes the following third-party components:

- iconv ( https://www.gnu.org/software/libiconv/ )
  See license in the file licenses/iconv.txt
- gettext ( https://www.gnu.org/software/gettext/ )
  See license in the file licenses/gettext.txt
- Unicode CLDR ( https://cldr.unicode.org/ )
  See license in the file licenses/cldr.txt
'@

$license = Join-Path -Path $Path -ChildPath 'licenses/gcc.txt'
if (Test-Path -LiteralPath $license -PathType Leaf) {
  if ($binaries.MinGWFilesAdded.Count -gt 0) {
    Add-LicenseText @'
- The GCC ( https://gcc.gnu.org/ ) runtime libraries provided by mingw-w64
  See license in the file licenses/gcc.txt
'@
  } else {
    Remove-Item -LiteralPath $license
  }
}
$license = Join-Path -Path $Path -ChildPath 'licenses/curl.txt'
if (Test-Path -LiteralPath $license -PathType Leaf) {
    if ($binaries.CurlFilesPresent) {
        Add-LicenseText @'
- curl ( https://curl.se/ )
  See license in the file licenses/curl.txt
'@
    } else {
        Remove-Item -LiteralPath $license
        Add-LicenseText @'
- curl ( https://curl.se/ )
  Used in source form
'@
    }
}
$license = Join-Path -Path $Path -ChildPath 'licenses/json-c.txt'
    if (Test-Path -LiteralPath $license -PathType Leaf) {
    if ($binaries.JsonCFilesPresent) {
        Add-LicenseText @'
- JSON-C ( https://github.com/json-c/json-c )
  See license in the file licenses/json-c.txt
'@
    } else {
        Remove-Item -LiteralPath $license
        Add-LicenseText @'
- JSON-C ( https://github.com/json-c/json-c )
  Used in source form

'@
    }
}
