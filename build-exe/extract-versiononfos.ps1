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
    if ($file.Name -like 'iconv.exe') {
        $versionParameterName = 'iconvPEVersion'
    } elseif ($file.Name -like 'libiconv-*.dll') {
        $versionParameterName = 'iconvPEVersion'
    } elseif ($file.Name -like 'libcurl*.dll') {
        $versionParameterName = 'curlPEVersion'
    } elseif ($file.Name -like 'libjson-c*.dll') {
        $versionParameterName = 'jsonCPEVersion'
    } elseif ($file.Name -like 'envsubst.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'gettext.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'libgettextlib-*.dll') {
        $nameParameterName = 'gettextPENameLibGettextLib'
        $versionParameterName = 'gettextPEVersionLibGettextLib'
    } elseif ($file.Name -like 'libgettextsrc-*.dll') {
        $nameParameterName = 'gettextPENameLibGettextSrc'
        $versionParameterName = 'gettextPEVersionLibGettextSrc'
    } elseif ($file.Name -like 'libintl-*.dll') {
        $versionParameterName = 'gettextPEVersionLibIntl'
    } elseif ($file.Name -like 'libtextstyle-*.dll') {
        $versionParameterName = 'gettextPEVersionLibTextStyle'
    } elseif ($file.Name -like 'msgattrib.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgcat.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgcmp.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgcomm.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgconv.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgen.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgexec.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgfilter.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgfmt.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msggrep.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msginit.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgmerge.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgpre.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msgunfmt.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'msguniq.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'ngettext.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'printf_gettext.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'printf_ngettext.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'recode-sr-latin.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'spit.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'xgettext.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'cldr-plurals.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'hostname.exe') {
        $versionParameterName = 'gettextPEVersion'
    } elseif ($file.Name -like 'urlget.exe') {
        $versionParameterName = 'gettextPEVersion'
    } else {
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
