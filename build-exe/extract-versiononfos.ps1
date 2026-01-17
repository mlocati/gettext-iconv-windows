# Script that checks if the .exe and .dll files have the expected values for VERSIONINFO

param (
    [Parameter(Mandatory = $true)] [ValidateLength(1, [int]::MaxValue)] [string] $RootPath
)

function Export-Variable()
{
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $false)]
        [string] $Value
    )
    "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

function Set-ScriptVar {
    param (
        [string]$Name,
        [string]$Value
    )
    $oldValue = Get-Variable -Name $Name -Scope Script -ValueOnly
    if ($oldValue -eq '') {
        Set-Variable -Name $Name -Value $Value -Scope Script
    } elseif ($oldValue -ne $Value) {
        throw "'$Name' was previously defined to be '$oldValue', but now we're trying to set it to '$Value'."
    }
}

if (-not(Test-Path -LiteralPath $RootPath -PathType Container)) {
    throw "Unable to find the directory $RootPath"
}

$script:iconvPEVersion = ''
$script:curlPEVersion = ''
# $script:jsonCPEVersion = '' # DISABLED - SEE https://github.com/json-c/json-c/issues/912
$script:gettextPEVersion = ''
$script:libgettextlibPEName = ''
$script:libgettextlibPEVersion = ''
$script:libgettextsrcPEName = ''
$script:libgettextsrcPEVersion = ''
$script:libintlPEVersion = ''
$script:libtextstylePEVersion = ''

$files = Get-ChildItem -LiteralPath $RootPath -File -Recurse -Include *.exe,*.dll
foreach ($file in $files) {
    $nameVariableName = ''
    $versionVariableName = ''
    if ($file.Name -like 'iconv.exe') {
        $versionVariableName = 'iconvPEVersion'
    } elseif ($file.Name -like 'libiconv-*.dll') {
        $versionVariableName = 'iconvPEVersion'
    } elseif ($file.Name -like 'libcurl*.dll') {
        $versionVariableName = 'curlPEVersion'
    <# DISABLED - SEE https://github.com/json-c/json-c/issues/912
    } elseif ($file.Name -like 'libjson-c*.dll') {
        $versionVariableName = 'jsonCPEVersion'
    #>
    } elseif ($file.Name -like 'envsubst.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'gettext.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'libgettextlib-*.dll') {
        $nameVariableName = 'libgettextlibPEName'
        $versionVariableName = 'libgettextlibPEVersion'
    } elseif ($file.Name -like 'libgettextsrc-*.dll') {
        $nameVariableName = 'libgettextsrcPEName'
        $versionVariableName = 'libgettextsrcPEVersion'
    } elseif ($file.Name -like 'libintl-*.dll') {
        $versionVariableName = 'libintlPEVersion'
    } elseif ($file.Name -like 'libtextstyle-*.dll') {
        $versionVariableName = 'libtextstylePEVersion'
    } elseif ($file.Name -like 'msgattrib.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgcat.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgcmp.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgcomm.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgconv.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgen.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgexec.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgfilter.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgfmt.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msggrep.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msginit.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgmerge.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgpre.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgunfmt.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msguniq.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'ngettext.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'printf_gettext.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'printf_ngettext.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'recode-sr-latin.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'spit.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'xgettext.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'cldr-plurals.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'hostname.exe') {
        $versionVariableName = 'gettextPEVersion'
    } elseif ($file.Name -like 'urlget.exe') {
        $versionVariableName = 'gettextPEVersion'
    } else {
        continue
    }
    Write-Output "## File: $($file.Name)"
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName)
    if (-not($versionInfo)) {
        throw 'No version information found!'
    }
    if ($nameVariableName -ne '') {
        Write-Output "- $($versionInfo.ProductName) => $nameVariableName"
        Set-ScriptVar -Name $nameVariableName -Value $versionInfo.ProductName
    }
    if ($versionVariableName -ne '') {
        Write-Output "- $($versionInfo.ProductVersion) => $versionVariableName"
        Set-ScriptVar -Name $versionVariableName -Value $versionInfo.ProductVersion
    }
}

Export-Variable -Name 'iconv-peversion' -Value $script:iconvPEVersion
Export-Variable -Name 'curl-peversion' -Value $script:curlPEVersion
# Export-Variable -Name 'json-c-peversion' -Value $script:jsonCPEVersion # DISABLED - SEE https://github.com/json-c/json-c/issues/912
Export-Variable -Name 'gettext-peversion' -Value $script:gettextPEVersion
Export-Variable -Name 'libgettextlib-pename' -Value $script:libgettextlibPEName
Export-Variable -Name 'libgettextlib-peversion' -Value $script:libgettextlibPEVersion
Export-Variable -Name 'libgettextsrc-pename' -Value $script:libgettextsrcPEName
Export-Variable -Name 'libgettextsrc-peversion' -Value $script:libgettextsrcPEVersion
Export-Variable -Name 'libintl-peversion' -Value $script:libintlPEVersion
Export-Variable -Name 'libtextstyle-peversion' -Value $script:libtextstylePEVersion

Write-Output '## Outputs'
Get-Content -LiteralPath $env:GITHUB_OUTPUT
