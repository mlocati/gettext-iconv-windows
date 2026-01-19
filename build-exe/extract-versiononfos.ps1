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
    "$Name<<EOF" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    $Value | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "EOF" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

if (-not(Test-Path -LiteralPath $RootPath -PathType Container)) {
    throw "Unable to find the directory $RootPath"
}

$collectedData = @{}

$files = Get-ChildItem -LiteralPath $RootPath -File -Recurse -Include *.exe,*.dll
foreach ($file in $files) {
    $nameParameterName = ''
    $versionParameterName = ''
    switch -Wildcard ($file.Name) {
        # Iconf
        'iconv.exe' {
            $versionParameterName = 'iconvPEVersion'
        }
        'libiconv-*.dll' {
            $versionParameterName = 'iconvPEVersion'
        }
        # curl
        'libcurl*.dll' {
            $versionParameterName = 'curlPEVersion'
        }
        # JSON-C
        'libjson-c*.dll' {
            $versionParameterName = 'jsonCPEVersion'
        }
        # Gettext
        'envsubst.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'gettext.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'libgettextlib-*.dll' {
            $nameParameterName = 'gettextPENameLibGettextLib'
            $versionParameterName = 'gettextPEVersionLibGettextLib'
        }
        'libgettextsrc-*.dll' {
            $nameParameterName = 'gettextPENameLibGettextSrc'
            $versionParameterName = 'gettextPEVersionLibGettextSrc'
        }
        'libintl-*.dll' {
            $versionParameterName = 'gettextPEVersionLibIntl'
        }
        'libtextstyle-*.dll' {
            $versionParameterName = 'gettextPEVersionLibTextStyle'
        }
        'msgattrib.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgcat.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgcmp.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgcomm.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgconv.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgen.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgexec.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgfilter.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgfmt.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msggrep.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msginit.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgmerge.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgpre.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msgunfmt.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'msguniq.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'ngettext.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'printf_gettext.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'printf_ngettext.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'recode-sr-latin.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'spit.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'xgettext.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'cldr-plurals.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'hostname.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        'urlget.exe' {
            $versionParameterName = 'gettextPEVersion'
        }
        # Files missing details
        # - see https://signpath.org/terms#signpath-configuration-requirements
        # - see https://lists.gnu.org/archive/html/bug-gettext/2024-09/msg00049.html
        # - see https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00058.html
        'csharpexec-test.exe' {
            continue
        }
        'GNU.Gettext.dll' {
            continue
        }
        'libasprintf-*.dll' {
            continue
        }
        'libcharset-*.dll' {
            continue
        }
        'libgettextpo-*.dll' {
            continue
        }
        'msgfmt.net.exe' {
            continue
        }
        'msgunfmt.net.exe' {
            continue
        }
        # MinGW-w64 files:
        # - see https://signpath.org/terms#conditions-for-what-can-be-signed
        # - see https://signpath.org/terms#signpath-configuration-requirements
        # - see https://sourceforge.net/p/mingw-w64/mailman/message/58822390/
        # - see https://github.com/niXman/mingw-builds/issues/684
        'libgcc_s_seh-*.dll' {
            continue
        }
        'libgcc_s_sjlj-*.dll' {
            continue
        }
        'libstdc++-*.dll' {
            continue
        }
        'libwinpthread-*.dll' {
            continue
        }
        default {
            throw "Unexpected file name: $($file.Name)"
        }
    }
    if ($versionParameterName -eq '' -and $nameParameterName -eq '') {
        continue
    }
    Write-Output "## File: $($file.Name)"
    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.FullName)
    if (-not($versionInfo)) {
        throw 'No version information found!'
    }
    if ($nameParameterName -ne '') {
        $value = if ($versionInfo -and $versionInfo.ProductName) { $versionInfo.ProductName } else { '' }
        if ($value -eq '') {
            throw 'ProductName not found!'
        }
        Write-Output "- '$value' => $nameParameterName"
        if ($collectedData.ContainsKey($nameParameterName)) {
            if ($collectedData[$nameParameterName] -ne $value) {
                throw "Conflicting values collected for '$nameParameterName': '$($collectedData[$nameParameterName])' vs '$value'"
            }
        } else {
            $collectedData[$nameParameterName] = $value
        }
    }
    if ($versionParameterName -ne '') {
        $value = if ($versionInfo -and $versionInfo.ProductVersion) { $versionInfo.ProductVersion } else { '' }
        if ($value -eq '') {
            throw 'ProductVersion not found!'
        }
        Write-Output "- '$value' => $versionParameterName"
        if ($collectedData.ContainsKey($versionParameterName)) {
            if ($collectedData[$versionParameterName] -ne $value) {
                throw "Conflicting values collected for '$versionParameterName': '$($collectedData[$versionParameterName])' vs '$value'"
            }
        } else {
            $collectedData[$versionParameterName] = $value
        }
    }
}

$serializedLines = @()
foreach ($key in $collectedData.Keys) {
    $value = $collectedData[$key]
    if ($value -ne '') {
        $serializedLines += $key + ': ' + (ConvertTo-Json $value)
    }
}

$serializedParameters = ($serializedLines | Sort-Object) -join "`n"
Write-Output "`n## Collected parameters:`n$serializedParameters`n"
Export-Variable -Name 'signpath-parameters' -Value $serializedParameters
