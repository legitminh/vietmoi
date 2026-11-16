# Run in a matching-architecture Visual Studio Developer PowerShell with Swift
# from .swift-version and CMake installed. This builds the real Windows Swift DLL.
param([ValidateSet('x64','ARM64')][string]$Architecture = 'x64')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $expected = (Get-Content .swift-version -Raw).Trim()
    $version = (& swift --version | Out-String)
    if ($version -notmatch [regex]::Escape($expected)) { throw "Use Swift $expected; found $version" }
    python scripts/generate-design.py --check
    if ($LASTEXITCODE) { throw 'Generated design files are stale' }
    $scratch = "build/windows-swift-$Architecture"
    & swift build --configuration release --scratch-path $scratch --product SieuvietEngine
    if ($LASTEXITCODE) { throw 'Windows Swift engine build failed' }
    $binary = (& swift build --configuration release --scratch-path $scratch --show-bin-path | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE) { throw 'Cannot locate the engine binary' }
    $native = "build/windows-native-$Architecture"
    & cmake -S Desktop -B $native -A $Architecture
    if ($LASTEXITCODE) { throw 'CMake configure failed' }
    & cmake --build $native --config Release --parallel 2
    if ($LASTEXITCODE) { throw 'Windows native adapter build failed' }
    $stage = Join-Path $root "build/windows-package-$Architecture"
    New-Item -ItemType Directory -Force $stage | Out-Null
    & cmake --install $native --config Release --prefix $stage
    if ($LASTEXITCODE) { throw 'Windows native install staging failed' }
    Copy-Item (Join-Path $native 'Release/desktop-session-tests.exe') $stage
    Copy-Item (Join-Path $binary 'SieuvietEngine.dll') $stage
    # Official toolchains place runtime DLLs in target runtime paths and usr/bin.
    $target = (& swift -print-target-info | ConvertFrom-Json)
    $swiftBin = Split-Path (Get-Command swift).Source -Parent
    $runtimePaths = @($swiftBin, (Join-Path (Split-Path $swiftBin -Parent) 'lib/swift/windows')) + @($target.paths.runtimeLibraryPaths)
    # Current Windows installers can keep runtime DLLs in a separate Runtimes
    # directory on PATH, rather than beside the compiler or .lib files.
    $runtimePaths += @($env:Path -split ';' | Where-Object { $_ -and (Test-Path (Join-Path $_ 'swiftCore.dll')) })
    if ($env:SDKROOT) { $runtimePaths += (Join-Path $env:SDKROOT 'usr/bin') }
    foreach ($path in ($runtimePaths | Select-Object -Unique)) {
        if (Test-Path $path) { Get-ChildItem $path -Filter '*.dll' -File | Copy-Item -Destination $stage }
    }
    # Include the matching redistributable CRT rather than relying on Visual
    # Studio or a separately installed redistributable on the user's machine.
    $crtRoot = Join-Path $env:VCToolsRedistDir $Architecture
    $crt = @(Get-ChildItem $crtRoot -Directory -Filter 'Microsoft.VC*.CRT')
    if (!$crt.Count) { throw "No matching Visual C++ redistributable CRT found in $crtRoot" }
    foreach ($directory in $crt) {
        Get-ChildItem $directory.FullName -Filter '*.dll' -File | Copy-Item -Destination $stage
    }
    # Loading and exercising the packaged library catches missing DLLs, ABI and
    # architecture mismatches. Do not register the text service if this fails.
    $originalPath = $env:Path
    try {
        $env:Path = "$stage;$env:SystemRoot\System32;$env:SystemRoot"
        & (Join-Path $stage 'desktop-session-tests.exe') (Join-Path $stage 'SieuvietEngine.dll')
        if ($LASTEXITCODE) { throw 'Packaged Windows shared-engine checks failed' }
    } finally { $env:Path = $originalPath }
    Copy-Item Design/brand.json (Join-Path $stage 'release.json')
    Write-Host "Built and smoke-tested $stage. Run its install.ps1 elevated for TSF registration; test typing separately."
} finally { Pop-Location }
