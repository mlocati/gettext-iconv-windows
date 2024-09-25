# Script that creates the installer

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet(32, 64)]
    [int] $bits,
    [Parameter(Mandatory = $true)]
    [ValidateSet('shared', 'static')]
    [string] $link,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $outputPath
)

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
        "#define MyVersionShownName `"$link ($bits bit)`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        "#define MyVersionCodeName `"$link-$bits`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        if ($bits -eq 64) {
            "#define MyIs64bit true" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        } else {
            "#define MyIs64bit false" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
        }
        "#define MyGettextVer `"$env:GETTEXT_VERSION`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
		"#define MyIconvVer `"$env:ICONV_VERSION`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
		"#define MyCompiledFolderPath `"$outputPath`"" | Out-File -FilePath $temporaryFile -Append -Encoding utf8
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
$outputFolder = 'C:\'
$outputFile = "gettext$env:GETTEXT_VERSION-iconv$env:ICONV_VERSION-$link-$bits"
$issFile = New-IssFile
try {
    & ISCC.exe /O"$outputFolder" /F"$outputFile" "$issFile"
    if (-not($?)) {
        throw "ISCC.exe failed"
    }
    Write-Host -Object "$outputFile has been created in $outputFolder"
} finally {
    Remove-Item -LiteralPath $issFile -ErrorAction SilentlyContinue
}
