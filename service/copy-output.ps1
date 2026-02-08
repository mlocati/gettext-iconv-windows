[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'IconvVersion', Justification = 'Not used at this time, but it is passed for future use')]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'exe')]
    [string] $Type,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $From,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $To
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

function Get-RelativePath {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $AbsolutePath,
        [Parameter(Mandatory = $false)]
        [string]
        $RootDirectory
    )
    if (!$RootDirectory) {
        $RootDirectory = $script:FromDirectory
    }
    $RootDirectory = $RootDirectory.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $AbsolutePath.StartsWith($RootDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "The source path '$AbsolutePath' is not located within the from directory '$RootDirectory'."
    }
    return $AbsolutePath.Substring($RootDirectory.Length).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
}

function Test-CopyFile {
    [OutputType([bool], [string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $SourceRelativePath
    )
    if ($SourceRelativePath -eq 'license.txt') {
        return $true
    }
    if ($SourceRelativePath -like 'licenses/*') {
        if ($Type -eq 'dev' -and (
            $SourceRelativePath -like '*/cldr.txt' -or
            $SourceRelativePath -like '*/curl.txt' -or
            $SourceRelativePath -like '*/json-c.txt'
        )) {
            # We don't have CLDR, curl or JSON-C stuff in the developers' packages
            return $false
        }
        return $true
    }
    if ($SourceRelativePath -like 'bin/*.txt') {
        return $true
    }
    if ($SourceRelativePath -like 'bin/*.dll') {
        if ($Type -eq 'dev' -and (
            $SourceRelativePath -match '/(lib)?curl(-\d+)?\.dll$' -or
            $SourceRelativePath -match '/(lib)?json-c(-\d+)?\.dll$'
        )) {
            # We don't have curl or JSON-C stuff in the developers' packages
            return $false
        }
        return $true
    }
    if ($SourceRelativePath -like 'bin/*.exe') {
        return $Type -eq 'exe'
    }
    if ($SourceRelativePath -like 'lib/*.a' -or $SourceRelativePath -like 'lib/*.lib') {
        if ($Type -eq 'exe') {
            return $false
        }
        if ($SourceRelativePath -match '/(lib)?curl(-\d+)?\.(\.dll)?(a|lib)$' -or
            $SourceRelativePath -match '/(lib)?json-c(-\d+)?\.(\.dll)?(a|lib)$'
        ) {
            # We don't have curl or JSON-C stuff in the developers' packages
            return $false
        }
        return $true
    }
    if ($SourceRelativePath -like 'include/*') {
        if ($Type -eq 'exe') {
            return $false
        }
        if ($SourceRelativePath -match '^include/(curl|json-c)(/|$)') {
            # We don't have curl or JSON-C stuff in the developers' packages
            return $false
        }
        return $true
    }
    if ($SourceRelativePath -like 'lib/*.dll') {
        return $true
    }
    if ($SourceRelativePath -like 'lib/*.exe') {
        return $Type -eq 'exe'
    }
    if ($SourceRelativePath -like 'libexec/*.dll') {
        return $true
    }
    if ($SourceRelativePath -like 'libexec/*.exe') {
        return $Type -eq 'exe'
    }
    if ($SourceRelativePath -like 'share/doc/gettext/examples/*') {
        # Copied later if Type == dev
        return $false
    }
    if ($SourceRelativePath -like 'share/doc/*.html') {
        if ($SourceRelativePath -match '^share/doc/.*\.[2-9]\.html' -or
            $SourceRelativePath -like 'share/doc/*autopoint.1.html' -or
            $SourceRelativePath -like 'share/doc/*gettextize.1.html' -or
            $SourceRelativePath -like 'share/doc/gettext/csharpdoc*' -or
            $SourceRelativePath -like 'share/doc/gettext/javadoc2*' -or
            $SourceRelativePath -like 'share/doc/libasprintf*' -or
            $SourceRelativePath -like 'share/doc/libtextstyle*'
        ) {
            return $Type -eq 'dev'
        }
        if ($Type -ne 'exe') {
            return $false
        }
        if ($SourceRelativePath -like 'share/doc/*.1.html') {
            return  $SourceRelativePath -replace '\.1\.html$','.html'
        }
        return $true
    }
    if ($SourceRelativePath -like 'share/gettext*.h' -or
        $SourceRelativePath -like 'share/iconv*.h'
    ) {
        return $Type -eq 'dev'
    }
    if ($SourceRelativePath -like 'share/gettext*/cldr/*' -or
        $SourceRelativePath -like 'share/gettext*/its/*' -or
        $SourceRelativePath -like 'share/gettext*/schema/*' -or
        $SourceRelativePath -like 'share/gettext*/styles/*' -or
        $SourceRelativePath -like 'share/gettext*/*.tcl'
    ) {
        if ($Type -eq 'dev') {
            return $false
        }
        return $SourceRelativePath -replace '^share/gettext[^/]*/','share/gettext/'
    }
    if ($SourceRelativePath -like 'share/*.class' -or $SourceRelativePath -like 'share/*.m4' -or $SourceRelativePath -like 'share/*.pc') {
        return $Type -eq 'dev'
    }
    return $false
}

function Copy-SourceFile {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $SourceRelativePath,
        [Parameter(Mandatory = $false)]
        [string]
        $DestinationRelativePath
    )
    $sourcePath = Join-Path -Path $script:FromDirectory -ChildPath $SourceRelativePath
    if (-not $DestinationRelativePath) {
        $DestinationRelativePath = $SourceRelativePath
    }
    $message = $SourceRelativePath
    if ($DestinationRelativePath -cne $SourceRelativePath) {
        $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $DestinationRelativePath
        $message += " -> $DestinationRelativePath"
    } else {
        $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $SourceRelativePath
    }
    $destinationDirectory = Split-Path -Path $destinationPath -Parent
    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }
    if ( $SourceRelativePath -like '*.txt') {
        Write-Host "$message (converting line endings)"
        $content = Get-Content -Raw $sourcePath
        $content = $content -replace '\r?\n', "`r`n"
        Set-Content -LiteralPath $destinationPath -Value $content -NoNewline
    } else {
        Write-Host $message
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
    }
}

function Copy-SourceDirectory {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $SourceRelativePath,
        [Parameter(Mandatory = $false)]
        [string]
        $DestinationRelativePath
    )
    $sourcePath = Join-Path -Path $script:FromDirectory -ChildPath $SourceRelativePath
    if (-not $DestinationRelativePath) {
        $DestinationRelativePath = $SourceRelativePath
    }
    $message = "$SourceRelativePath/"
    if ($DestinationRelativePath -cne $SourceRelativePath) {
        $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $DestinationRelativePath
        $message += " -> $DestinationRelativePath/"
    } else {
        $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $SourceRelativePath
    }
    Write-Host $message
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Recurse -Force
}

function Remove-DestinationItem {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DestinationRelativePath
    )
    $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $DestinationRelativePath
    if (Test-Path -LiteralPath $destinationPath -PathType Container) {
        Write-Host "$DestinationRelativePath/ -> removed"
        Remove-Item -LiteralPath $destinationPath -Force -Recurse
    } elseif (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        Write-Host "$DestinationRelativePath -> removed"
        Remove-Item -LiteralPath $destinationPath -Force
    }
}

$script:FromDirectory = [System.IO.Path]::GetFullPath($From).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$script:ToDirectory = [System.IO.Path]::GetFullPath($To).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar).TrimEnd([System.IO.Path]::DirectorySeparatorChar)

$inGithub = $env:GITHUB_ACTIONS -eq 'true'

if ($inGithub) {
    Write-Host '::group::Contents of input directory'
    $items = Get-ChildItem -Path $script:FromDirectory -Recurse -File | ForEach-Object {
        Get-RelativePath -AbsolutePath $_.FullName
    } | Sort-Object
    foreach ($item in $items) {
        Write-Host $item
    }
    Write-Host '::endgroup::'
}

if ($inGithub) {
    Write-Host '::group::Copying files'
}
Get-ChildItem $script:FromDirectory -File -Recurse | ForEach-Object {
    $relativePath = Get-RelativePath -AbsolutePath $_.FullName
    $shouldCopy = Test-CopyFile $relativePath
    if ($shouldCopy -is [string]) {
        Copy-SourceFile $relativePath $shouldCopy
    } elseif ($shouldCopy) {
        Copy-SourceFile $relativePath
    }
}
switch ($Type) {
    'dev' {
        Copy-SourceDirectory 'share/doc/gettext/examples'
    }
    'exe' {
        Copy-SourceDirectory 'share/locale'
    }
}
if ($inGithub) {
    Write-Host '::endgroup::'
}

if ($inGithub) {
    Write-Host '::group::Contents of output directory'
    $items = Get-ChildItem -Path $script:ToDirectory -Recurse -File | ForEach-Object {
        Get-RelativePath -AbsolutePath $_.FullName -RootDirectory $script:ToDirectory
    } | Sort-Object
    foreach ($item in $items) {
        Write-Host $item
    }
    Write-Host '::endgroup::'
}
