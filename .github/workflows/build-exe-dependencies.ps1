<#
$Env:PATH += ";C:\Program Files (x86)\Microsoft Visual Studio\Installer"
#>

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
    [string] $outputPath,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $mingwPath
)

function Find-Dumpbin
{
    [OutputType([string])]
    $vsPath = & vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not($?)) {
        throw "vswhere failed"
    }
    $vcToolsVersion = Get-Content -LiteralPath "$vsPath\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" -TotalCount 1
    switch ($bits) {
        32 {
            $result = "$vsPath\VC\Tools\MSVC\$vcToolsVersion\bin\Hostx86\x86\dumpbin.exe"
        }
        64 {
            $result = "$vsPath\VC\Tools\MSVC\$vcToolsVersion\bin\HostX64\x64\dumpbin.exe"
        }
    }
    if (-not(Test-Path -LiteralPath $result -PathType Leaf)) {
        throw "$result`ndoes not exist"
    }
    $result
}

function Get-Dependencies()
{
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
        [string] $path
    )

    $dumpbinResult = & "$dumpbin" /NOLOGO /DEPENDENTS "$path"
    if (-not($?)) {
        throw "dumpbin failed to analyze the file $($path)"
    }
    [string[]]$dependencies = @()
    $started = $false
    foreach ($line in $dumpbinResult) {
        $line = $line.Trim()
        if (-not($line)) {
            continue;
        }
        if ($started) {
            if ($line -eq 'Summary') {
                break
            }
            $dependencies += $line.ToLowerInvariant()
        } elseif ($line -eq 'Image has the following dependencies:') {
            $started = $true
        }
    }
    $dependencies | Sort-Object
}

class Binary
{
    [System.IO.FileInfo] $File
    [string[]] $Dependencies
    Binary([System.IO.FileInfo]$file)
    {
        $this.File = $file
        $this.Dependencies = Get-Dependencies $this.File.FullName
    }
}

class Binaries
{
    [bool] $MinGWFilesAdded = $false

    [Binary[]] $Items

    Binaries()
    {
        $this.Items = @()
    }

    [void] Add([Binary]$binary)
    {
        if ($this.GetBinaryByName($binary.File.Name)) {
            throw "Duplicated binary name $($binary.File.Name)"
        }
        $this.Items += $binary
    }

    [Binary] GetBinaryByName([string] $name)
    {
        foreach ($item in $this.Items) {
            if ($item.File.Name -eq $name) {
                return $item
            }
        }
        return $null
    }

    [void] RemoveUnusedDlls()
    {
        do {
            $repeat = $false
            foreach ($binary in $this.Items) {
                if ($binary.File.Extension -ne '.dll') {
                    continue
                }
                $name = $binary.File.Name.ToLowerInvariant()
                $unused = $true
                foreach ($other in $this.Items) {
                    if ($other -ne $binary -and $other.Dependencies -contains $name) {
                        $unused = $false
                        break
                    }
                }
                if ($unused) {
                    Write-Host -Object "$($binary.File.Name) is never used: deleting it"
                    $binary.File.Delete()
                    $this.Items = $this.Items | Where-Object { $_ -ne $binary }
                    $repeat = $true
                    break
                }
            }
        } while ($repeat)
    }

    [void] AddMingwDlls([string] $mingwBinPath)
    {
        $checkedDeps = @()
        for ($index = 0; $index -lt $this.Items.Count; $index++) {
            $binary = $this.Items[$index]
            foreach ($dependency in $binary.Dependencies) {
                if ($checkedDeps -contains $dependency) {
                    continue
                }
                $checkedDeps += $dependency
                if ($this.GetBinaryByName($dependency)) {
                    continue
                }
                $mingwDllPath = Join-Path -Path $mingwBinPath -ChildPath $dependency
                if (-not(Test-Path -LiteralPath $mingwDllPath -PathType Leaf)) {
                    continue
                }
                Write-Host -Object "Adding MinGW DLL $dependency"
                Copy-Item -LiteralPath $mingwDllPath -Destination $binary.File.Directory
                $newFilePath = Join-Path -Path $binary.File.Directory -ChildPath $dependency
                $newFile = Get-ChildItem -LiteralPath $newFilePath -File
                $newBinary = [Binary]::new($newFile)
                $this.Add($newBinary)
                $this.MinGWFilesAdded = $true
            }
        }
    }

    [void] Dump()
    {
        $binaries = $this.Items | Sort-Object -Property {  $_.File.Name }
        foreach ($binary in $binaries) {
            Write-Host -Object "Dependencies of $($binary.File.Name)"
            if ($binary.Dependencies) {
                foreach ($dependency in $binary.Dependencies) {
                    Write-Host -Object "  - $dependency"
                }
            } else {
                Write-Host -Object '  (none)'
            }
        }
    }
}

$dumpbin = Find-Dumpbin
$mingwBinPath = Join-Path -Path $mingwPath -ChildPath 'sys-root\mingw\bin'
$outputBinPath = Join-Path -Path $outputPath -ChildPath 'bin'
$binaries = [Binaries]::new()
foreach ($file in Get-ChildItem -LiteralPath $outputBinPath -Recurse -File) {
    if ($file.Extension -eq '.exe' -or $file.Extension -eq '.dll') {
        $binary = [Binary]::new($file)
        $binaries.Add($binary)
    }
}

$binaries.RemoveUnusedDlls()
$binaries.AddMingwDlls($mingwBinPath)
if ($binaries.MinGWFilesAdded) {
    Write-Host -Object "Adding MinGW-w64 license"
    $mingwLicenseFile = Join-Path -Path $outputPath -ChildPath 'mingw-license.txt'
    $mingwLicense = $(Invoke-WebRequest -Uri 'https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/COPYING.MinGW-w64-runtime/COPYING.MinGW-w64-runtime.txt?format=raw').ToString()
    $mingwLicense -ireplace "`r`n","`n" -ireplace "`n","`r`n" | Set-Content -LiteralPath $mingwLicenseFile -NoNewline -Encoding utf8
}

$binaries.Dump()
