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
