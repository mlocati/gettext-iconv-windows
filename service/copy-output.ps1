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
    $message = "- $SourceRelativePath"
    if ($DestinationRelativePath -and $DestinationRelativePath -cne $SourceRelativePath) {
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
    $message = "- $SourceRelativePath/"
    if ($DestinationRelativePath -and $DestinationRelativePath -cne $SourceRelativePath) {
        $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $DestinationRelativePath
        $message += " -> $DestinationRelativePath/"
    } else {
        $destinationPath = Join-Path -Path $script:ToDirectory -ChildPath $SourceRelativePath
    }
    Write-Host $message
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Recurse -Force -ProgressAction SilentlyContinue
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
    switch -Wildcard ($relativePath) {
        'license*txt' {
            Copy-SourceFile $relativePath
            break
        }
        'bin/*.dll' {
            Copy-SourceFile $relativePath
            break
        }
        'bin/*.exe' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'bin/*.lib' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'lib/*.dll' {
            Copy-SourceFile $relativePath
            break
        }
        'lib/*.exe' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'lib/*.lib' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'libexec/*.dll' {
            Copy-SourceFile $relativePath
            break
        }
        'libexec/*.exe' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'libexec/*.lib' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'share/doc/gettext/examples/*' {
            # Copied later if TYPE=dev
            break
        }
        'share/doc/*.html' {
            if ($relativePath -match '^share/doc/.*\.[2-9]\.html' -or
                $relativePath -like 'share/doc/*autopoint.1.html' -or
                $relativePath -like 'share/doc/*gettextize.1.html' -or
                $relativePath -like 'share/doc/gettext/csharpdoc*' -or
                $relativePath -like 'share/doc/gettext/javadoc2*' -or
                $relativePath -like 'share/doc/libasprintf*' -or
                $relativePath -like 'share/doc/libtextstyle*'
            ) {
                if ($Type -eq 'dev') {
                    Copy-SourceFile $relativePath
                }
            } elseif ($relativePath -like 'share/doc/*.1.html') {
                if ($Type -eq 'exe') {
                    Copy-SourceFile $relativePath ($relativePath -replace '\.1\.html$','.html')
                }
            } elseif ($Type -eq 'exe') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'share/gettext/cldr/*' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath
            }
            break
        }
        'share/gettext*/its/*' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath ($relativePath -replace '^share/gettext[^/]*/', 'share/gettext/')
            }
            break
        }
        'share/gettext*/schema/*' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath ($relativePath -replace '^share/gettext[^/]*/', 'share/gettext/')
            }
            break
        }
        'share/gettext*/styles/*' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath ($relativePath -replace '^share/gettext[^/]*/', 'share/gettext/')
            }
            break
        }
        '*.tcl' {
            if ($Type -eq 'exe') {
                Copy-SourceFile $relativePath
            }
            break
        }
        '*.a' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        '*.h' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        '*.class' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        '*.cmake' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        '*.m4' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
        '*.pc' {
            if ($Type -eq 'dev') {
                Copy-SourceFile $relativePath
            }
            break
        }
    }
}
switch ($Type) {
    'dev' {
        Copy-SourceDirectory 'include'
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
