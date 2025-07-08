# Script that checks if a .exe or a .dll file has the expected values for VERSIONINFO

param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [ValidateLength(0, [int]::MaxValue)]
    [string] $ExpectedProductName,
    [Parameter(Mandatory = $true)]
    [ValidateLength(0, [int]::MaxValue)]
    [string] $ExpectedProductVersion
)

$result = $true
Write-Host -Object "Checking version information for $($Path):"
if (-not(Test-Path -LiteralPath $Path -PathType Leaf)) {
    Write-Host -Object '- file not found (but required to exist)' -ForegroundColor Red
    $result = $false
} else {
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file)
    if (-not($versionInfo)) {
        Write-Host -Object '- no version information found' -ForegroundColor Red
        $result = $false
    } else {
        if ($versionInfo.ProductName -eq $ExpectedProductName) {
            Write-Host -Object "- ProductName matches expected value ($($ExpectedProductName))" -ForegroundColor Green
        } else {
            Write-Host -Object "- ProductName ($($versionInfo.ProductName)) does not match expected value ($($ExpectedProductName))" -ForegroundColor Red
            $result = $false
        }
        if ($versionInfo.ProductVersion -eq $ExpectedProductVersion) {
            Write-Host -Object "- ProductVersion matches expected value ($($ExpectedProductVersion))" -ForegroundColor Green
        } else {
            Write-Host -Object "- ProductVersion ($($versionInfo.ProductVersion)) does not match expected value ($($ExpectedProductVersion))" -ForegroundColor Red
            $result = $false
        }
    }
}

return $result
