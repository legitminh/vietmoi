# Vietnamese by default. Use -Language en for English.
param([switch]$Uninstall, [ValidateSet('vi','en')][string]$Language = 'vi')
$ErrorActionPreference = 'Stop'
$copy = Get-Content (Join-Path $PSScriptRoot 'install-copy.json') -Raw -Encoding utf8 | ConvertFrom-Json
function Text([string]$Key) { return $copy.$Key.$Language }
$adapter = Join-Path $PSScriptRoot 'SieuvietTSF.dll'
if (!(Test-Path $adapter)) { throw (Text 'installWindowsMissingAdapter') }
if (!$Uninstall) {
    if (!(Test-Path (Join-Path $PSScriptRoot 'SieuvietEngine.dll'))) { throw (Text 'installWindowsMissingEngine') }
    $smoke = Join-Path $PSScriptRoot 'desktop-session-tests.exe'
    if (!(Test-Path $smoke)) { throw (Text 'installWindowsMissingSmoke') }
    & $smoke (Join-Path $PSScriptRoot 'SieuvietEngine.dll') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw (Text 'installWindowsSmokeFailed') }
}
$regsvr = Join-Path $env:SystemRoot 'System32/regsvr32.exe'
$registrationArgs = @('/s'); if ($Uninstall) { $registrationArgs += '/u' }; $registrationArgs += "`"$adapter`""
$process = Start-Process $regsvr -ArgumentList $registrationArgs -Wait -PassThru
if ($process.ExitCode -ne 0) { throw (Text 'installWindowsRegistrationFailed') }
Write-Host (Text $(if ($Uninstall) { 'installWindowsRemoved' } else { 'installWindowsRegistered' }))
