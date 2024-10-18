# Script dump the "product-name" and "product-version" properties .dll and .exe files

param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_})]
    [string] $Path
)

function Read-File()
{
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $Path,
        [Parameter(Mandatory = $false)]
        [System.IO.DirectoryInfo] $RelativeTo

    )
    if ($RelativeTo) {
        $displayName = $Path.FullName.Substring($RelativeTo.FullName.Length + 1).Replace('\', '/')
    } else {
        $displayName = $Path.Name
    }
    $versionInfo = $Path.VersionInfo
    $productName = $versionInfo ? $versionInfo.ProductName : ''
    $productVersion = $versionInfo ? $versionInfo.ProductVersion : ''
    Write-Output @"
${displayName}:
    product-name="$productName"
    product-version="$productVersion"
"@
}

$Path = $Path.TrimEnd('/').TrimEnd('\')
$parent = Get-Item -LiteralPath $Path
if ($parent.PSIsContainer) {
    $files = Get-ChildItem -Path $Path -Recurse -File -Include *.exe,*.dll
    foreach ($file in $files) {
        Read-File -Path $file -RelativeTo $parent
    }
} else {
    Read-File -Path $Path
}