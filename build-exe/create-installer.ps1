# Script that creates the installer

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
    [string] $SourceDirectory,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $OutputDirectory
)

$SourceDirectory = [System.IO.Path]::GetFullPath($SourceDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

function GetIssSourceFile()
{
    [OutputType([string])]
    $PSCommandPath -replace '\.[^.]+$','.iss'
}

function New-IssFile()
{
    [OutputType([string])]
    $templateFile = $PSCommandPath -replace '\.[^.]+$','.iss'
    $deleteTemporaryFile = $true
    $temporaryFile = New-TemporaryFile
    try {
        "#define MyVersionShownName `"$Link ($Bits bit)`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        "#define MyVersionCodeName `"$Link-$Bits`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        if ($Bits -eq 64) {
            "#define MyIs64bit true" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        } else {
            "#define MyIs64bit false" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        }
        "#define MyGettextVer `"$env:GETTEXT_VERSION`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        "#define MyIconvVer `"$env:ICONV_VERSION`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        "#define MyCompiledFolderPath `"$SourceDirectory`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        Get-Content -LiteralPath $templateFile -Encoding utf8 | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        $deleteTemporaryFile = $false
        $temporaryFile
    } finally {
        if ($deleteTemporaryFile) {
            Remove-Item -LiteralPath $temporaryFile -ErrorAction SilentlyContinue
        }
    }
}

if (-not($env:ICONV_VERSION)) {
    throw 'Missing ICONV_VERSION environment variable'
}
if (-not($env:GETTEXT_VERSION)) {
    throw 'Missing GETTEXT_VERSION environment variable'
}
$outputFile = "gettext$env:GETTEXT_VERSION-iconv$env:ICONV_VERSION-$Link-$Bits"
$issFile = New-IssFile
try {
    & ISCC.exe /O"$OutputDirectory" /F"$outputFile" "$issFile"
    if (-not($?)) {
        throw "ISCC.exe failed"
    }
    Write-Host -Object "$outputFile has been created in $OutputDirectory"
} finally {
    Remove-Item -LiteralPath $issFile -ErrorAction SilentlyContinue
}
