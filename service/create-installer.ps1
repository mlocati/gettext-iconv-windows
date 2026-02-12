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
    [string] $OutputDirectory,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $IconvVersion,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $GettextVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$SourceDirectory = [System.IO.Path]::GetFullPath($SourceDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

function GetIssSourceFile()
{
    [OutputType([string])]
    $PSCommandPath -replace '\.[^.]+$','.iss'
}

function Format-IssLanguageFile {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $LanguageFile
    )
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($LanguageFile.Name)
    if ($baseName -eq 'default') {
        $languageCode = 'default'
        $InnosetupLanguagefile = 'compiler:Default.isl'
    } else {
        $languageCode, $InnosetupLanguagefile = $baseName -split '\.',2
        $InnosetupLanguagefile = "compiler:Languages\$InnosetupLanguagefile.isl"
    }
    return "  + NewLine + `"Name: `"`"$languageCode`"`"; MessagesFile: `"`"$InnosetupLanguagefile,$($LanguageFile.FullName)`"`"`" \"
}

function Initialize-Iss()
{
    [OutputType([string])]
    $includeFile = $PSCommandPath -replace '\.[^.]+$','.isi'
    $templateFile = $PSCommandPath -replace '\.[^.]+$','.iss'
    Remove-Item -LiteralPath $includeFile -ErrorAction SilentlyContinue
    "#define MyVersionShownName `"$Link ($Bits bit)`"" | Add-Content -LiteralPath $includeFile -Encoding utf8
    "#define MyVersionCodeName `"$Link-$Bits`"" | Add-Content -LiteralPath $includeFile -Encoding utf8
    if ($Bits -eq 64) {
    "#define MyIs64bit true" | Add-Content -LiteralPath $includeFile -Encoding utf8
    } else {
        "#define MyIs64bit false" | Add-Content -LiteralPath $includeFile -Encoding utf8
    }
    "#define MyGettextVer `"$GettextVersion`"" | Add-Content -LiteralPath $includeFile -Encoding utf8
    "#define MyIconvVer `"$IconvVersion`"" | Add-Content -LiteralPath $includeFile -Encoding utf8
    "#define MyCompiledFolderPath `"$SourceDirectory`"" | Add-Content -LiteralPath $includeFile -Encoding utf8
    "#define MyOutputFolderPath `"$OutputDirectory`"" | Add-Content -LiteralPath $includeFile -Encoding utf8
    '#define MyLanguages "" \' | Add-Content -LiteralPath $includeFile -Encoding utf8
    $languageFiles = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath "create-installer\*.isl") -File
    $defaultLanguageFile = $languageFiles | Where-Object -Property Name -EQ 'default.isl'
    if (-not $defaultLanguageFile) {
        throw "Default language file not found"
    }
    Format-IssLanguageFile -LanguageFile $defaultLanguageFile | Add-Content -LiteralPath $includeFile -Encoding utf8
    foreach ($languageFile in $languageFiles) {
        if ($languageFile -ne $defaultLanguageFile) {
            Format-IssLanguageFile -LanguageFile $languageFile | Add-Content -LiteralPath $includeFile -Encoding utf8
        }
    }
    '  + ""' | Add-Content -LiteralPath $includeFile -Encoding utf8

    return $templateFile
}

$outputFile = "gettext$GettextVersion-iconv$IconvVersion-$Link-$Bits"
$issFile = Initialize-Iss
& ISCC.exe /O"$OutputDirectory" /F"$outputFile" "$issFile"
if (-not($?)) {
    throw "ISCC.exe failed"
}
Write-Host -Object "$outputFile has been created in $OutputDirectory"
