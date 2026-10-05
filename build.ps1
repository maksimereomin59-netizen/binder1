[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$builder = Join-Path $root 'tools\build.py'

if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
    [Console]::Error.WriteLine('Cannot find tools/build.py. Run this from the MedBind project folder.')
    exit 1
}

$python = Get-Command 'py.exe' -ErrorAction SilentlyContinue
if ($python) {
    $pythonArgs = @('-3', $builder)
} else {
    $python = Get-Command 'python.exe' -ErrorAction SilentlyContinue
    if (-not $python) {
        [Console]::Error.WriteLine('Python 3 is required to build. Install Python 3 or run DoctorBinder.ahk directly.')
        exit 1
    }
    $pythonArgs = @($builder)
}

if ($Check) {
    $pythonArgs += '--check'
}

& $python.Source @pythonArgs
exit $LASTEXITCODE
