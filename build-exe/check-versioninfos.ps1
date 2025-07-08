# Script that checks if the .exe and .dll files have the expected values for VERSIONINFO

param (
    [Parameter(Mandatory = $true)] [ValidateLength(1, [int]::MaxValue)] [string] $RootPath,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $IconvPEVersion,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPEVersion,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPENameLibGettextLib,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPEVersionLibGettextLib,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPENameLibGettextSrc,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPEVersionLibGettextSrc,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPEVersionLibIntl,
    [Parameter(Mandatory = $true)] [ValidateLength(0, [int]::MaxValue)] [string] $GettextPEVersionLibTextStyle
)

$success = $true

$checker = Join-Path $PSScriptRoot 'check-versioninfo.ps1'
if (-not(Test-Path -LiteralPath $RootPath -PathType Container)) {
    throw "Unable to find the directory $RootPath"
}
$files = Get-ChildItem -LiteralPath $RootPath -File -Recurse -Include *.exe,*.dll
foreach ($file in $files) {
    $thisSuccess = $true
    if ($file.Name -like 'iconv.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'iconv: character set conversion program' -ExpectedProductVersion $IconvPEVersion
    } elseif ($file.Name -like 'libiconv-*.dll') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'libiconv: character set conversion library' -ExpectedProductVersion $IconvPEVersion
    } elseif ($file.Name -like 'envsubst.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'gettext.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'libgettextlib-*.dll') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName $GettextPENameLibGettextLib -ExpectedProductVersion $GettextPEVersionLibGettextLib
    } elseif ($file.Name -like 'libgettextsrc-*.dll') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName $GettextPENameLibGettextSrc -ExpectedProductVersion $GettextPEVersionLibGettextSrc
    } elseif ($file.Name -like 'libintl-*.dll') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU libintl: accessing NLS message catalogs' -ExpectedProductVersion $GettextPEVersionLibIntl
    } elseif ($file.Name -like 'libtextstyle-*.dll') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU libtextstyle: Text styling library' -ExpectedProductVersion $GettextPEVersionLibTextStyle
    } elseif ($file.Name -like 'msgattrib.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgcat.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgcmp.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgcomm.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgconv.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgen.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgexec.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgfilter.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgfmt.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msggrep.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msginit.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgmerge.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msgunfmt.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'msguniq.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'ngettext.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'recode-sr-latin.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'xgettext.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'cldr-plurals.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'hostname.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } elseif ($file.Name -like 'urlget.exe') {
        $thisSuccess = & $checker -Path $file.FullName -ExpectedProductName 'GNU gettext utilities' -ExpectedProductVersion $GettextPEVersion
    } else {
        continue
    }
    if (-not($thisSuccess)) {
        $success = $false
    }
}

if (-not($success)) {
    throw 'Some files do not have the expected VERSIONINFO values.'
}
