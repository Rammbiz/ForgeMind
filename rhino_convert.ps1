# ForgeMind: DWG -> STEP (3D) or DXF (2D) using Rhino's core headlessly.
#
# Rhino's interactive commands (-Open, -Export) raise modal option dialogs
# that cannot be suppressed from the command line, which hangs an
# unattended run and puts a window on the operator's screen. Loading the
# core in-process with WindowStyle.NoWindow has no GUI at all, so no
# dialog can ever appear.
#
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File rhino_convert.ps1 <source.dwg>
#
# Prints a final line for the caller to parse:
#   RESULT=3d;<path.stp>     solids found, exported as STEP
#   RESULT=2d;                curves only - see note below
# Exit code 0 on success, 1 on failure.
#
# Flat drawings are deliberately NOT exported here. Rhino's
# DWG/DXF writer emits DWG whatever extension it is handed, so a
# ".dxf" from it is really a DWG that no DXF reader will open.
# The caller converts those with the ODA File Converter instead,
# which is purpose-built for that one job.

param(
    [Parameter(Mandatory = $true)]
    [string]$Source
)

$ErrorActionPreference = 'Stop'

$RhinoSystem = 'C:\Program Files\Rhino 8\System'
$RhinoCommon = Join-Path $RhinoSystem 'RhinoCommon.dll'

function Fail($message) {
    Write-Output "ERROR: $message"
    exit 1
}

if (-not (Test-Path $Source)) { Fail "source not found: $Source" }
if (-not (Test-Path $RhinoCommon)) { Fail 'Rhino 8 is not installed on this machine.' }

$base = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName($Source),
    [System.IO.Path]::GetFileNameWithoutExtension($Source)
)

$core = $null

try {
    # Rhino's native libraries have to be resolvable before the core loads.
    $env:PATH = $RhinoSystem + ';' + $env:PATH

    Add-Type -Path $RhinoCommon

    $ctorArgs = New-Object object[] 2
    $ctorArgs[0] = [string[]]@('/nosplash')
    $ctorArgs[1] = [Rhino.Runtime.InProcess.WindowStyle]::NoWindow

    $core = New-Object Rhino.Runtime.InProcess.RhinoCore -ArgumentList $ctorArgs

    $doc = [Rhino.RhinoDoc]::CreateHeadless($null)

    if (-not $doc.Import($Source)) { Fail 'Rhino could not read this DWG.' }

    Write-Output "objects: $($doc.Objects.Count)"

    if ($doc.Objects.Count -eq 0) { Fail 'the DWG contains no geometry.' }

    # Solids decide the route: a 3D body goes out as STEP, a flat drawing
    # as DXF for the cut-map pipeline.
    $solids = 0

    foreach ($o in $doc.Objects) {
        $name = $o.Geometry.GetType().Name
        if ($name -in @('Brep', 'Extrusion', 'SubD', 'Mesh')) { $solids++ }
    }

    Write-Output "solid objects: $solids"

    if ($solids -eq 0) {

        # A flat drawing: leave it to the DXF converter.
        $doc.Dispose()
        Write-Output "RESULT=2d;"
        return
    }

    $target = $base + '.stp'

    if (-not $doc.Export($target)) { Fail "Rhino could not write $target" }

    $doc.Dispose()

    if (-not (Test-Path $target)) { Fail 'export reported success but no file appeared.' }

    Write-Output "RESULT=3d;$target"
}
catch {
    Write-Output "ERROR: $($_.Exception.GetType().Name): $($_.Exception.Message)"
    exit 1
}
finally {
    if ($core) { try { $core.Dispose() } catch { } }
}
