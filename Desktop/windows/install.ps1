# Run from an elevated PowerShell of the package's architecture. Keep this
# directory intact; registration points to its absolute DLL path.
param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$adapter = Join-Path $PSScriptRoot 'SieuvietTSF.dll'
if (!(Test-Path $adapter)) { throw 'SieuvietTSF.dll is missing' }
if (!$Uninstall) {
    if (!(Test-Path (Join-Path $PSScriptRoot 'SieuvietEngine.dll'))) { throw 'Build/package the Swift engine before registration' }
    $smoke = Join-Path $PSScriptRoot 'desktop-session-tests.exe'
    if (!(Test-Path $smoke)) { throw 'desktop-session-tests.exe is missing' }
    & $smoke (Join-Path $PSScriptRoot 'SieuvietEngine.dll')
    if ($LASTEXITCODE -ne 0) { throw 'Shared-engine smoke test failed; registration skipped' }
}
$regsvr = Join-Path $env:SystemRoot 'System32/regsvr32.exe'
$args = @('/s'); if ($Uninstall) { $args += '/u' }; $args += "`"$adapter`""
$process = Start-Process $regsvr -ArgumentList $args -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "TSF registration failed ($($process.ExitCode)). Check elevation and matching process/package architecture." }
if (!$Uninstall) { Write-Host 'Registered. Select Sieuviet with Win+Space. Open SieuvietSettings.exe for settings and a typing field.' }
