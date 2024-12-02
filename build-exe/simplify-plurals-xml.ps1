# Script that simplify the CLDR plural.xml so that it's parsable by cldr-plurals (see https://savannah.gnu.org/bugs/?66378)

param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
    [string] $InputPath,
    [Parameter(Mandatory = $false)]
    [string] $OutputPath
)

$xml = Get-Content -LiteralPath $InputPath -Raw -Encoding utf8NoBOM

# for gettext we can assume that c (compact decimal exponent value) and e (a deprecated synonym for 'c')
# are always 0.
# since (as of version 0.23) gettext doesn't recognize c and e, we replace them with v (assumed to be 0 by gettext)
while ($true) {
    $xml2 = $xml -creplace '(?<before>>[^"]*)\b[ce]\b','${before}v'
    if ($xml2 -eq $xml) {
        break
    }
    $xml = $xml2
}
# Strip examples like 1c3, 1.1c6
$xml = $xml -creplace '\b\d+(\.\d*)?c\d+,\s*',''
# Strip emppy examples (@decimal \u{2026})
$xml = $xml -replace "@\w+\s+`u{2026}\s*",''

if (-not($OutputPath)) {
    $OutputPath = $InputPath
}

Set-Content -LiteralPath $OutputPath -Value $xml -NoNewLine -Encoding utf8NoBOM
