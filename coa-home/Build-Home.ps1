# Builds a configured home build (see Configure-HomeBuild.ps1).
# The server PC also runs worldserver. An uncapped build runs a compiler on every core and the
# world drops to ~10 ticks/s (coa-home-server#46). So while worldserver is running, the build
# runs at below-normal priority with capped parallelism. With the server stopped it runs at full speed.
param(
    [string]$Build = 'C:\wow-server\coa\build',
    [string]$Config = 'Release',
    # Compiler processes at once while worldserver runs. Default: half the logical cores.
    [int]$Jobs = [math]::Max(2, [math]::Floor([Environment]::ProcessorCount / 2)),
    # Full speed even while worldserver runs.
    [switch]$FullSpeed,
    # Print the build command and settings, don't build.
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Join-Path $Build 'CMakeCache.txt'))) {
    throw "$Build is not configured; run coa-home\Configure-HomeBuild.ps1 -Build $Build first"
}

$serverUp = [bool](Get-Process worldserver -ErrorAction SilentlyContinue)
$throttle = $serverUp -and -not $FullSpeed

$cmakeArgs = @('--build', $Build, '--config', $Config)
if ($throttle) {
    # Two projects at a time, each compiling up to Jobs/2 files (cl /MP). /nr:false stops the build
    # from reusing MSBuild nodes left at normal priority by an earlier build.
    $perProject = [math]::Max(1, [math]::Floor($Jobs / 2))
    $cmakeArgs += @('--parallel', '2', '--', '/nr:false', "/p:CL_MPCount=$perProject")
    Write-Warning "worldserver is running: building at below-normal priority with at most $Jobs compiler processes. Use -FullSpeed to override, or stop the server for a full-speed build."
} elseif ($serverUp) {
    Write-Warning 'worldserver is running and -FullSpeed is set: the world will lag until the build ends.'
}

$mode = if ($throttle) { 'throttled' } else { 'full speed' }
Write-Host "cmake $($cmakeArgs -join ' ')  ($mode)"
if ($DryRun) { exit 0 }

if ($throttle) {
    # Lower this shell before cmake starts. Windows gives children of a below-normal process the
    # same class, so cmake, MSBuild, Tracker and every cl inherit it from the first process on.
    [Diagnostics.Process]::GetCurrentProcess().PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal
}
& cmake @cmakeArgs
exit $LASTEXITCODE
