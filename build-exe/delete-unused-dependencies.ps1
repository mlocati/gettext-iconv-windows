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
    [string] $Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot/../service/functions.ps1"

$binaries = [BinaryFileCollection]::new($Bits, $Path)

$removedCount = $binaries.RemoveUnusedDlls()

Write-Host -Object "`nRemoved $removedCount unused DLL(s)"

