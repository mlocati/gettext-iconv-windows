# Script that checks if a file (or the files in a directory) is signed

param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [bool] $CanBeInvalid
)

function Test-CanFileBeSigned()
{
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $file
    )
    $excludedNames = @(
        # MinGW-w64 files
        'libatomic-*.dll',
        'libgcc_s_sjlj-*.dll',
        'libgomp-*.dll',
        'libquadmath-*.dll',
        'libssp-*.dll',
        'libstdc++-*.dll',
        'libwinpthread-*.dll'
    )
    foreach ($excludedName in $excludedNames) {
        if ($file.Name -like $excludedName) {
            return $false
        }
    }

    return $true
}

function Test-File()
{
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $file
    )
    Write-Host -Object "$($file.Name)... " -NoNewLine
    if (-not(Test-CanFileBeSigned $file)) {
        Write-Host -Object 'skipped.'
    } else {
        $signature = Get-AuthenticodeSignature -FilePath $file.FullName
        $signatureType = $signature.SignatureType
        switch ($signatureType) {
            { 'Authenticode', 'Catalog' -eq $_ }  {
                $signatureStatus = $signature.Status
                if ($signatureStatus -ne 'Valid' -and -not($CanBeInvalid)) {
                    throw $signature.StatusMessage
                }
                Write-Host -Object "signed ($signatureType, $signatureStatus)"
            }
            'None' {
                throw "$($file.FullName) is not signed"
            }
            default {
                throw "$($file.FullName) has an unknown signature ($signatureType)"
            }
        }
    }
}

if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $file = Get-Item -LiteralPath $Path
    Test-File $file
} elseif (Test-Path -LiteralPath $Path -PathType Container) {
    foreach ($filter in @('*.exe', '*.dll')) {
        $files = Get-ChildItem -LiteralPath $Path -File -Filter $filter -Recurse
        foreach ($file in $files) {
            Test-File $file
        }
    }
} else {
    throw "Unable to find the file or directory $Path"
}
