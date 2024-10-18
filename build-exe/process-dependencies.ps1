# Script that process the "output directory, so that:
# - there are no unused DLLs
# - the required MinGW-w64 DLLs are included

[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'Bits', Justification = 'False positive as rule does not scan child scopes')]
[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'Link', Justification = 'Unused at the moment, but may be used in the future')]

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
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string] $MinGWPath
)

function Find-Dumpbin
{
    [OutputType([string])]
    $vsPath = & vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not($?)) {
        throw "vswhere failed"
    }
    $vcToolsVersion = Get-Content -LiteralPath "$vsPath\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" -TotalCount 1
    switch ($Bits) {
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
        [string] $BinaryPath
    )

    $dumpbinResult = & "$dumpbin" /NOLOGO /DEPENDENTS "$BinaryPath"
    if (-not($?)) {
        throw "dumpbin failed to analyze the file $BinaryPath"
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

function Get-ImportedFunctions()
{
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $importer,
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $dllName
    )
    $dumpbinResult = & "$dumpbin" /NOLOGO /DEPENDENTS $importer.FullName "/IMPORTS:$dllName"
    if (-not($?)) {
        throw "dumpbin failed to analyze the file $($importer)"
    }
    $state = 0
    $result = @()
    foreach ($line in $dumpbinResult) {
        if ($line -eq '') {
            continue
        }
        if ($line -match '^ *Summary$') {
            break;
        }
        if ($state -eq 0) {
            if ($line -match '^\s*Section contains the following imports:\s*$') {
                $state = 1
            }
        } elseif ($state -eq 1) {
            if ($line -like "* $dllName") {
                $state = 2
            }
        } elseif (-not($line -match '^       .*')) {
            break
        } elseif ($state -eq 2) {
             if ($line -match '^\s*\d+\s+Index of first forwarder reference$') {
                $state = 3
             }
        } else {
            if ($state -ne 3)  {
                throw 'Processing failed'
            }
            if (-not($line -match '^\s*[0-9A-Fa-f]+\s*(\w+)$')) {
                throw 'Processing failed'
            }
            $result += $matches[1]
        }
    }
    return $result
}


class Binary
{
    [System.IO.FileInfo] $File
    [string] $RelativePath
    [string[]] $Dependencies
    Binary([System.IO.FileInfo]$file, [System.IO.DirectoryInfo]$root)
    {
        $this.File = $file
        if (!$file.FullName.StartsWith($root.FullName + [System.IO.Path]::DirectorySeparatorChar)) {
            throw "File out of path: $($file.FullName)"
        }
        $this.RelativePath = $file.FullName.Substring($root.FullName.Length + 1).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
        $this.Dependencies = Get-Dependencies -BinaryPath $this.File.FullName
    }
}

class Binaries
{
    [System.IO.DirectoryInfo] $Root;

    [string[]] $MinGWFilesAdded = @()

    [Binary[]] $Items

    Binaries([string] $Path)
    {
        $this.Root = Get-Item -LiteralPath $Path
        $this.Items = @()
        foreach ($file in Get-ChildItem -LiteralPath $this.Root.FullName -Recurse -File -Include *.exe,*.dll) {
            $binary = [Binary]::new($file, $this.Root)
            $this.Add($binary)
        }
    }

    hidden [void] Add([Binary]$binary)
    {
        if ($this.GetBinaryByRelativePath($binary.RelativePath)) {
            throw "Duplicated binary name $($binary.RelativePath)"
        }
        $this.Items += $binary
    }

    [Binary] GetBinaryByRelativePath([string] $relativePath)
    {
        foreach ($item in $this.Items) {
            if ($relativePath -eq $item.RelativePath) {
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
                if (-not($binary.RelativePath -match '^bin/[^/]+\.dll$')) {
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
                    Write-Host -Object "$($binary.RelativePath) is never used: deleting it"
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
                if ($this.GetBinaryByRelativePath("bin/$dependency")) {
                    continue
                }
                $mingwDllPath = Join-Path -Path $mingwBinPath -ChildPath $dependency
                if (-not(Test-Path -LiteralPath $mingwDllPath -PathType Leaf)) {
                    continue
                }
                Write-Host -Object "Adding MinGW-w64 DLL $dependency"
                Copy-Item -LiteralPath $mingwDllPath -Destination $(Join-Path -Path $this.Root.FullName -ChildPath bin)
                $newFilePath = Join-Path -Path $this.Root.FullName -ChildPath "bin/$dependency"
                $newFile = Get-Item -LiteralPath $newFilePath
                $newBinary = [Binary]::new($newFile, $this.Root)
                $this.Add($newBinary)
                $this.MinGWFilesAdded += $dependency
            }
        }
    }

    [void] Dump()
    {
        $binaries = $this.Items | Sort-Object -Property {  $_.RelativePath }
        foreach ($binary in $binaries) {
            Write-Host -Object "Dependencies of $($binary.RelativePath)"
            if ($binary.Dependencies) {
                foreach ($dependency in $binary.Dependencies) {
                    Write-Host -Object "  - $dependency"
                }
            } else {
                Write-Host -Object '  (none)'
            }
        }
        if ($this.MinGWFilesAdded) {
            Write-Host -Object ''
            foreach ($minGWFileAdded in $this.MinGWFilesAdded) {
                Write-Host -Object "$minGWFileAdded added because:"
                foreach ($binary in $binaries) {
                    $functions = Get-ImportedFunctions $binary.File $minGWFileAdded
                    if (-not($functions)) {
                        continue
                    }
                    if ($this.MinGWFilesAdded -contains $binary.File.Name.ToLowerInvariant()) {
                        Write-Host -Object "  - $($binary.File.Name) requires it"
                    } else {
                        Write-Host -Object "  - $($binary.File.Name) uses its functions: $($functions -join ', ')"
                    }
                }
            }
        }
    }
}

$dumpbin = Find-Dumpbin
$mingwBinPath = Join-Path -Path $MinGWPath -ChildPath 'sys-root\mingw\bin'
$binaries = [Binaries]::new($Path)

$binaries.RemoveUnusedDlls()
$binaries.AddMingwDlls($mingwBinPath)
if ($binaries.MinGWFilesAdded) {
    Write-Host -Object "Adding MinGW-w64 license"
    $mingwLicenseFile = Join-Path -Path $Path -ChildPath 'license-mingw-w64.txt'
    $mingwLicense = $(Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/niXman/mingw-builds/refs/heads/develop/COPYING.TXT').ToString()
    $mingwLicense -replace "`r`n","`n" -replace "`n","`r`n" | Set-Content -LiteralPath $mingwLicenseFile -NoNewline -Encoding utf8
}

$binaries.Dump()
