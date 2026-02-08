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

$binaries = [BinaryFileCollection]::new($Bits, $Path)

if ($MinGWPath) {
  $mingwBinPath = Join-Path -Path $MinGWPath -ChildPath 'sys-root\mingw\bin'
  $binaries.AddMingwDlls($mingwBinPath)
}

$binaries.Dump()

$gccLicenseFile = Join-Path -Path $Path -ChildPath 'licenses/gcc.txt'
if (Test-Path -LiteralPath $gccLicenseFile -PathType Leaf) {
  if ($binaries.MinGWFilesAdded.Count -eq 0) {
    Remove-Item -LiteralPath $gccLicenseFile
  }
}
