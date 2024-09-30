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
        # Files missing details
        # - see https://signpath.org/terms#signpath-configuration-requirements
        # - see https://lists.gnu.org/archive/html/bug-gettext/2024-09/msg00049.html
        'libcharset-*.dll',
        'libgettextlib-*.dll',
        'libgettextpo-*.dll',
        'libgettextsrc-*.dll',
        # MinGW-w64 files:
        # - see https://signpath.org/terms#conditions-for-what-can-be-signed
        # - see https://signpath.org/terms#signpath-configuration-requirements
        # - see https://sourceforge.net/p/mingw-w64/mailman/message/58822390/
        # - see https://github.com/niXman/mingw-builds/issues/684
        'libatomic-*.dll', # mingw64-i686-gcc-core, mingw64-x86_64-gcc-core
        'libgcc_s_sjlj-*.dll', # mingw64-i686-gcc-core
        'libgcc_s_seh-*.dll', # mingw64-x86_64-gcc-core
        'libgomp-*.dll', # mingw64-i686-gcc-core, mingw64-x86_64-gcc-core
        'libquadmath-*.dll', # mingw64-i686-gcc-core, mingw64-x86_64-gcc-core
        'libssp-*.dll', # mingw64-i686-gcc-core, mingw64-x86_64-gcc-core
        'libstdc++-*.dll', # mingw64-i686-gcc, mingw64-x86_64-gcc-g++
        'libwinpthread-*.dll' # mingw64-i686-winpthreads, mingw64-x86_64-winpthreads
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
