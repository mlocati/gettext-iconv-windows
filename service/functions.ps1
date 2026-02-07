function ConvertTo-VersionObject()
{
    [OutputType([Version])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $Version
    )
    if ($Version -match '^[0-9]+(\.[0-9]+){0,3}') {
        $chunks = $matches[0] -split '\.'
        while ($chunks.Count -lt 4) {
            $chunks += '0'
        }
        return [Version]("$($chunks[0]).$($chunks[1]).$($chunks[2]).$($chunks[3])")
    }
    throw "Invalid Version: '$Version'"
}

function Compare-Versions {
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [Alias('Version1')]
        [Object] $Left,
        [Parameter(Mandatory = $true)]
        [Alias('Version2')]
        [Object] $Right
    )
    if ($Left -is [string]) {
        $Left = ConvertTo-VersionObject $Left
    } elseif (-not ($Left -is [Version])) {
        throw "Invalid Left version: $Left"
    }
    if ($Right -is [string]) {
        $Right = ConvertTo-VersionObject $Right
    } elseif (-not ($Right -is [Version])) {
        throw "Invalid Right version: $Right"
    }

    return $Left.CompareTo($Right)
}

function ConvertTo-CygwinPath()
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string[]] $WindowsPath
    )
    $match = Select-String -InputObject $WindowsPath -Pattern '^([A-Za-z]):(\\.*)$'
    if (!$match) {
        throw "Invalid value of WindowsPath '$WindowsPath'"
    }
    return '/cygdrive/' + $match.Matches.Groups[1].Value.ToLowerInvariant() + $match.Matches.Groups[2].Value.Replace('\', '/')
}

function Test-ServerAvailable()
{
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Url
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 5 -ErrorAction SilentlyContinue
        if (-not $response) {
            return $false
        }
    } catch {
        return $false
    }
    return $true
}

function Add-GithubOutput()
{
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [Parameter(Mandatory = $false)]
        [string] $Value
    )
    if ($null -eq $Value -or $Value -notmatch "[`r`n]") {
        "$Name=$Value" | Add-Content -Path $env:GITHUB_OUTPUT -Encoding utf8
    } else {
        $eof = "EOF_$([guid]::NewGuid().ToString('N'))"
        @("$Name<<$eof", $Value, $eof) | Add-Content -Path $env:GITHUB_OUTPUT -Encoding utf8
    }
}

function Get-GitHubOutputs()
{
    [OutputType([string])]
    param()

    if (Test-Path -LiteralPath $env:GITHUB_OUTPUT) {
        Get-Content -LiteralPath $env:GITHUB_OUTPUT
    }
}

function Find-DumpbinPath
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet(32, 64)]
        [int] $Bits
    )
    $vsPath = & vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not($?)) {
        throw 'vswhere failed'
    }
    if (-not($vsPath) -or -not(Test-Path -LiteralPath $vsPath -PathType Container)) {
        throw 'Visual Studio not found'
    }
    $vcToolsVersion = Get-Content -LiteralPath "$vsPath\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" -TotalCount 1
    switch ($Bits) {
        32 {
            $result = "$vsPath\VC\Tools\MSVC\$vcToolsVersion\bin\Hostx86\x86\dumpbin.exe"
        }
        64 {
            $result = "$vsPath\VC\Tools\MSVC\$vcToolsVersion\bin\Hostx64\x64\dumpbin.exe"
        }
    }
    if (-not(Test-Path -LiteralPath $result -PathType Leaf)) {
        throw "$result`ndoes not exist"
    }
    $result
}

class BinaryFile
{
    [System.IO.FileInfo] $File

    [string] $RelativePath

    [string[]] $Dependencies

    BinaryFile([System.IO.FileInfo] $file, [System.IO.DirectoryInfo] $root, [string[]] $dependencies)
    {
        $this.File = $file
        if (!$file.FullName.StartsWith($root.FullName + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "File out of path: $($file.FullName)"
        }
        $this.RelativePath = $file.FullName.Substring($root.FullName.Length + 1).Replace([System.IO.Path]::DirectorySeparatorChar, '/')
        $this.Dependencies = $dependencies
    }
}

class BinaryFileCollection
{
    hidden [string] $DumpbinPath;

    [System.IO.DirectoryInfo] $RootDir;

    [string[]] $MinGWFilesAdded = @()

    [bool] $CurlFilesPresent = $false

    [bool] $JsonCFilesPresent = $false

    [BinaryFile[]] $Items

    BinaryFileCollection([int] $bits, [string] $rootDirPath)
    {
        $this.DumpbinPath = Find-DumpbinPath -Bits $bits
        $this.RootDir = Get-Item -LiteralPath $rootDirPath
        $this.Items = @()
        foreach ($file in Get-ChildItem -LiteralPath $this.RootDir.FullName -Recurse -File -Include *.exe,*.dll) {
            if ($file.Extension -ne '.dll' -and $file.Extension -ne '.exe') {
                continue;
            }
            if ($file.Name -match '^libcurl.*\.dll$') {
                $this.CurlFilesPresent = $true
            }
            if ($file.Name -match '^libjson-c.*\.dll$') {
                $this.JsonCFilesPresent = $true
            }
            $this.Add([BinaryFile]::new($file, $this.RootDir, $this.GetDependencies($file)))
        }
    }

    hidden [string[]] GetDependencies([System.IO.FileInfo] $file)
    {
        $dumpbinResult = & $this.DumpbinPath /NOLOGO /DEPENDENTS $file.FullName
        if (-not($?)) {
            throw "dumpbin failed to analyze the file $($file.FullName)"
        }
        [string[]] $dependencies = @()
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
        return $dependencies | Sort-Object
    }

    hidden [void] Add([BinaryFile] $binaryFile)
    {
        if ($this.GetBinaryByRelativePath($binaryFile.RelativePath)) {
            throw "Duplicated binary file name $($binaryFile.RelativePath)"
        }
        $this.Items += $binaryFile
    }

    hidden [BinaryFile] GetBinaryByRelativePath([string] $relativePath)
    {
        foreach ($item in $this.Items) {
            if ($relativePath -eq $item.RelativePath) {
                return $item
            }
        }
        return $null
    }

    [int] RemoveUnusedDlls()
    {
        $removedCount = 0
        do {
            $repeat = $false
            foreach ($binaryFile in $this.Items) {
                if (-not($binaryFile.RelativePath -match '^bin/[^/]+\.dll$')) {
                    continue
                }
                $name = $binaryFile.File.Name.ToLowerInvariant()
                $unused = $true
                foreach ($other in $this.Items) {
                    if ($other -ne $binaryFile -and $other.Dependencies -contains $name) {
                        $unused = $false
                        break
                    }
                }
                if ($unused) {
                    Write-Host -Object "$($binaryFile.RelativePath) is never used: deleting it"
                    $binaryFile.File.Delete()
                    $this.Items = $this.Items | Where-Object { $_ -ne $binaryFile }
                    $removedCount++
                    $repeat = $true
                    break
                }
            }
        } while ($repeat)
        return $removedCount
    }

    [void] AddMingwDlls([string] $mingwBinPath)
    {
        $checkedDeps = @()
        for ($index = 0; $index -lt $this.Items.Count; $index++) {
            $binaryFile = $this.Items[$index]
            foreach ($dependency in $binaryFile.Dependencies) {
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
                Copy-Item -LiteralPath $mingwDllPath -Destination $(Join-Path -Path $this.RootDir.FullName -ChildPath bin)
                $newFilePath = Join-Path -Path $this.RootDir.FullName -ChildPath "bin/$dependency"
                $newFile = Get-Item -LiteralPath $newFilePath
                $newBinary = [BinaryFile]::new($newFile, $this.RootDir, $this.GetDependencies($newFile))
                $this.Add($newBinary)
                $this.MinGWFilesAdded += $dependency
            }
        }
    }

    hidden [string[]] ListImportedFunctions([System.IO.FileInfo] $importer, [string] $dllName)
    {
        $dumpbinResult = & $this.DumpbinPath /NOLOGO /DEPENDENTS $importer.FullName "/IMPORTS:$dllName"
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

    [void] Dump()
    {
        $binaries = $this.Items | Sort-Object -Property {  $_.RelativePath }
        foreach ($binaryFile in $binaries) {
            Write-Host -Object "Dependencies of $($binaryFile.RelativePath)"
            if ($binaryFile.Dependencies) {
                foreach ($dependency in $binaryFile.Dependencies) {
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
                foreach ($binaryFile in $binaries) {
                    $functions = $this.ListImportedFunctions($binaryFile.File, $minGWFileAdded)
                    if (-not($functions)) {
                        continue
                    }
                    if ($this.MinGWFilesAdded -contains $binaryFile.File.Name.ToLowerInvariant()) {
                        Write-Host -Object "  - $($binaryFile.File.Name) requires it"
                    } else {
                        Write-Host -Object "  - $($binaryFile.File.Name) uses its functions: $($functions -join ', ')"
                    }
                }
            }
        }
    }
}

class VCVars
{
    static [string[]] $PATH_LISTS = @('PATH', 'INCLUDE', 'EXTERNAL_INCLUDE', 'LIB', 'LIBPATH', 'WindowsLibPath')
    hidden [hashtable] $all
    hidden [hashtable] $delta

    VCVars([int] $bits)
    {
        $varLists = [VCVars]::CollectVarLists($bits)
        $previousVars = [VCVars]::ExtractVariables($varLists.PreviousVarsLines)
        $this.all = [VCVars]::ExtractVariables($varLists.NewVarsLines)
        $this.delta = [VCVars]::ComputeDeltaVars($previousVars, $this.all)
    }

    [string[]] GetIncludeDirs()
    {
        if (-not($this.all.ContainsKey('INCLUDE'))) {
            throw 'INCLUDE variable not found'
        }
        return $this.all['INCLUDE'];
    }

    [string[]] GetLibDirs()
    {
        if (-not($this.all.ContainsKey('LIB'))) {
            throw 'LIB variable not found'
        }
        return $this.all['LIB'];
    }

    [string[]] GetPathDirs()
    {
        if (-not($this.delta.ContainsKey('PATH'))) {
            throw "vcvarsall didn't modify the PATH variable"
        }
        return $this.delta['PATH'];
    }

    static hidden [pscustomobject] CollectVarLists([int] $bits)
    {
        $vcVarsAllPath = [VCVars]::FindVCVarsAll()
        $arch = switch ($bits) {
            32 { 'x86' }
            64 { 'x64' }
            Default { throw "Unsupported architecture bits: $bits" }
        }
        $sep = '[----------SEPARATOR----------]'
        $command = "set INCLUDE= && set LIB= && set PATH=%SystemRoot%\System32;%SystemRoot% && set && echo $sep && `"$vcVarsAllPath`" $arch >NUL && echo $sep && set"
        $lines = cmd.exe /c $command
        if (-not($?)) {
            throw "Failed to run vcvarsall.bat for architecture '$arch'"
        }
        $step = 1
        $previousVarsLines = @()
        $newVarsLines = @()
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -eq $sep) {
                $step++
                continue
            }
            switch ($step) {
                1 {
                    $previousVarsLines += $line
                    continue
                }
                2 {
                    continue
                }
                3 {
                    $newVarsLines += $line
                    continue
                }
                Default {
                    throw 'Unexpected step value'
                }
            }
        }
        if ($step -ne 3) {
            throw 'Failed to parse vcvarsall.bat output'
        }
        return @{
            PreviousVarsLines = $previousVarsLines
            NewVarsLines = $newVarsLines
        }
    }

    static hidden [string] FindVCVarsAll()
    {
        $vsPath = & vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if (-not($?)) {
            throw 'vswhere failed'
        }
        if (-not($vsPath) -or -not(Test-Path -LiteralPath $vsPath -PathType Container)) {
            throw 'Visual Studio not found'
        }
        return [System.IO.Path]::Combine($vsPath, 'VC', 'Auxiliary', 'Build', 'vcvarsall.bat')
    }

    static hidden [hashtable] ExtractVariables([string[]] $setOutput)
    {
        $variables = @{}
        foreach ($line in $setOutput) {
            if (-not($line -match '^([^=]+)=(.*)$')) {
                continue
            }
            $name = $matches[1]
            $value = $matches[2]
            if ([VCVars]::PATH_LISTS -contains $name) {
                $values = @()
                foreach ($v in $value -split ';') {
                    $v = [VCVars]::NormalizePath($v)
                    if ($v -ne '' -and $values -inotcontains $v) {
                        $values += $v
                    }
                }
                $variables[$name] = $values
            } else {
                $variables[$name] = $value
            }
        }
        return $variables
    }

    static hidden [string] NormalizePath([string] $path)
    {
        $path = $path.Trim()
        if ($path -notmatch '^[a-zA-Z]:[/\\]') {
            return $path
        }
        $path = $path -replace '/','\'
        $path = $path -replace '\\+','\'
        $path = $path -replace '\\$',''
        if ($path -match '^[a-zA-Z]:$') {
            $path += '\'
        }
        return $path
    }

    static hidden [hashtable] ComputeDeltaVars([hashtable] $previousVars, [hashtable] $newVars)
    {
        $result = @{}
        foreach ($name in $newVars.Keys) {
            $newValue = $newVars[$name]
            if (-not($previousVars.ContainsKey($name))) {
                $result[$name] = $newValue
                continue
            }
            $previousValue = $previousVars[$name]
            if ($newValue -is [array]) {
                $diff = $newValue | Where-Object { $_ -notin $previousValue }
                if ($diff -and ($diff.Count -gt 0)) {
                    $result[$name] = $diff
                }
            } else {
                if ($previousValue -ne $newValue) {
                    $result[$name] = $newValue
                }
            }
        }
        return $result
    }
}

function Get-RemoteRepositoryCommitDate
{
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, [int]::MaxValue)]
        [string] $RepositoryUrl,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{7,40}$')]
        [string] $CommitHash
    )
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        git -C $tempDir init -q | Out-Null
        if (-not $?) {
            throw 'git init failed'
        }
        git -C $tempDir remote add origin $RepositoryUrl | Out-Null
        if (-not $?) {
            throw 'git remote add failed'
        }
        git -C $tempDir fetch -q --depth 1 origin $CommitHash | Out-Null
        if (-not $?) {
            throw "git fetch failed for commit $CommitHash from $RepositoryUrl"
        }
        $date = git -C $tempDir show -s --format=%cd --date=format:%Y%m%d $CommitHash
        if (-not $?) {
            throw 'git show failed'
        }
        return $date.Trim()
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
