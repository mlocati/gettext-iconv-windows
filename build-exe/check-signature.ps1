# Script that checks if a file (or the files in a directory) is signed

[Diagnostics.CodeAnalysis.SuppressMessage('PSReviewUnusedParameter', 'CanBeInvalid', Justification = 'False positive as rule does not scan child scopes')]

param (
    [Parameter(Mandatory = $true)]
    [ValidateLength(1, [int]::MaxValue)]
    [string] $Path,
    [Parameter(Mandatory = $true)]
    [bool] $CanBeInvalid
)

function Test-MustFileBeSigned()
{
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $File
    )
    $excludedNames = @(
        # Files missing details
        # - see https://signpath.org/terms#signpath-configuration-requirements
        # - see https://lists.gnu.org/archive/html/bug-gettext/2024-09/msg00049.html
        # - see https://lists.gnu.org/archive/html/bug-gettext/2024-10/msg00058.html
        'GNU.Gettext.dll',
        'libcharset-*.dll',
        'libgettextlib-*.dll',
        'libgettextpo-*.dll',
        'libgettextsrc-*.dll',
        'msgfmt.net.exe',
        'msgunfmt.net.exe',
        # MinGW-w64 files:
        # - see https://signpath.org/terms#conditions-for-what-can-be-signed
        # - see https://signpath.org/terms#signpath-configuration-requirements
        # - see https://sourceforge.net/p/mingw-w64/mailman/message/58822390/
        # - see https://github.com/niXman/mingw-builds/issues/684
        'libgcc_s_seh-*.dll', # mingw64-x86_64-gcc-core
        'libgcc_s_sjlj-*.dll', # mingw64-i686-gcc-core
        'libwinpthread-*.dll' # mingw64-i686-winpthreads, mingw64-x86_64-winpthreads
    )
    foreach ($excludedName in $excludedNames) {
        if ($File.Name -like $excludedName) {
            return $false
        }
    }

    return $true
}

function Test-File()
{
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $File
    )
    Write-Host -Object "$($File.Name)... " -NoNewLine
    $signature = Get-AuthenticodeSignature -FilePath $File.FullName
    $signatureType = $signature.SignatureType
    $errors = @()
    switch ($signatureType) {
        { 'Authenticode', 'Catalog' -eq $_ }  {
            $signatureStatus = $signature.Status
            if ($signatureStatus -ne 'Valid' -and -not($CanBeInvalid)) {
                $errors += "$($File.FullName) has an invalid signature ($signatureStatus)"
            } else {
                Write-Host -Object "signed ($signatureType, $signatureStatus)"
            }
        }
        'None' {
            if (Test-MustFileBeSigned -File $File) {
                $errors += "$($File.FullName) is not signed"
            } else {
                Write-Host -Object 'skipped.'
            }
        }
        default {
            $errors += "$($File.FullName) has an unknown signature ($signatureType)"
        }
    }
    return $errors
}

$errors = @()
if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $file = Get-Item -LiteralPath $Path
    $errors += Test-File -File $file
} elseif (Test-Path -LiteralPath $Path -PathType Container) {
    $files = Get-ChildItem -LiteralPath $Path -File -Recurse -Include *.exe,*.dll
    foreach ($file in $files) {
        $errors += Test-File -File $file
    }
} else {
    $errors += "Unable to find the file or directory $Path"
}

if ($errors.Count -gt 0) {
    Write-Host -Object "`nErrors found:`n$($errors -join "`n")`n"
    exit 1
}
