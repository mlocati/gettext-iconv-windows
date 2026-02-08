param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $Url,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $LocalFilePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-FileHeaderBytes {
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $Path,
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Count
    )
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = New-Object byte[] $Count
        $read = $fs.Read($buffer, 0, $Count)
        if ($read -lt $Count) {
            return $buffer[0..($read-1)]
        }
        return $buffer
    }
    finally {
        $fs.Dispose()
    }
}

function Test-HeaderBytes {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [byte[]] $HeaderBytes,
        [Parameter(Mandatory = $true)]
        [byte[]] $ExpectedBytes
    )
    if ($HeaderBytes.Length -ne $ExpectedBytes.Length) {
        return $false
    }
    for ($i = 0; $i -lt $HeaderBytes.Length; $i++) {
        if ($HeaderBytes[$i] -ne $ExpectedBytes[$i]) {
            return $false
        }
    }
    return $true
}

function Test-GZipArchive {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $Path
    )
    $headerBytes = Get-FileHeaderBytes -Path $Path -Count 2
    return (Test-HeaderBytes -HeaderBytes $headerBytes -ExpectedBytes @(0x1F, 0x8B))
}

function Test-XZArchive {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $Path
    )
    # .7zXZ.
    $headerBytes = Get-FileHeaderBytes -Path $Path -Count 6
    return (Test-HeaderBytes -HeaderBytes $headerBytes -ExpectedBytes @(0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00))
}

function Test-ZipArchive {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $Path
    )
    $headerBytes = Get-FileHeaderBytes -Path $Path -Count 4
    # PK..
    return (Test-HeaderBytes -HeaderBytes $headerBytes -ExpectedBytes @(0x50, 0x4B, 0x03, 0x04)) -or # local header
        (Test-HeaderBytes -HeaderBytes $headerBytes -ExpectedBytes @(0x50, 0x4B, 0x05, 0x06)) -or # empty archive
        (Test-HeaderBytes -HeaderBytes $headerBytes -ExpectedBytes @(0x50, 0x4B, 0x07, 0x08)) # spanned archive
}

function Test-IsBrokenArchive {
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string]
        $Path
    )
    switch -Wildcard ($Path) {
        '*.gz' {
            return -not (Test-GZipArchive -Path $Path)
        }
        '*.nupkg' {
            return -not (Test-ZipArchive -Path $Path)
        }
        '*.tgz' {
            return -not (Test-GZipArchive -Path $Path)
        }
        '*.xz' {
            return -not (Test-XZArchive -Path $Path)
        }
        '*.zip' {
            return -not (Test-ZipArchive -Path $Path)
        }
    }
    return $false
}

if (Test-Path -Path $LocalFilePath -PathType Leaf) {
    if (Test-IsBrokenArchive -Path $LocalFilePath) {
        Write-Warning "File at $LocalFilePath appears to be corrupted. Deleting and re-downloading."
        Remove-Item -Path $LocalFilePath -Force
    } else {
        Write-Host "File already exists at $LocalFilePath. Skipping download."
        return
    }
}

$dir = Split-Path -Parent $LocalFilePath
if ($dir -and -not (Test-Path -Path $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}


Write-Host "Downloading archive from $Url to $LocalFilePath..."
try {
    Invoke-WebRequest -Uri $Url -OutFile $LocalFilePath -MaximumRedirection 10 -UseBasicParsing
} catch {
    Write-Error "Failed to download the file from $Url. Error: $_"
    throw
}
if (-not (Test-Path -Path $LocalFilePath -PathType Leaf)) {
    throw "The file was not downloaded successfully to $LocalFilePath."
}
if (Test-IsBrokenArchive -Path $LocalFilePath) {
    Remove-Item -Path $LocalFilePath -Force
    throw 'The downloaded file appears to be corrupted or incomplete.'
}
Write-Host 'Download completed successfully.'
