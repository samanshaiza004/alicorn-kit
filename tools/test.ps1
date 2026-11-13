param(
    [string]$Odin = 'odin'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$AlicornRoot = Join-Path $RepoRoot 'alicorn'
$Lock = Get-Content -LiteralPath (Join-Path $RepoRoot 'dependencies.lock.json') -Raw | ConvertFrom-Json
$AlicornHead = (& git -C $AlicornRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $AlicornHead -cne $Lock.alicorn.revision) {
    throw "Alicorn must be checked out at the locked revision $($Lock.alicorn.revision); found '$AlicornHead'."
}

$AlicornAccessKitPin = Get-Content -LiteralPath (Join-Path $AlicornRoot 'dependencies\odin-accesskit.json') -Raw | ConvertFrom-Json
if ($AlicornAccessKitPin.repository -cne $Lock.accesskit_binding.repository -or
    $AlicornAccessKitPin.commit -cne $Lock.accesskit_binding.revision) {
    throw 'AliKit and Alicorn AccessKit binding pins disagree; update dependencies.lock.json deliberately.'
}
$AccessKitRoot = Join-Path $AlicornRoot '.deps\odin-accesskit'
$AccessKitHead = (& git -C $AccessKitRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $AccessKitHead -cne $Lock.accesskit_binding.revision) {
    throw "AccessKit binding must be checked out at $($Lock.accesskit_binding.revision); found '$AccessKitHead'."
}

$OdinCommand = Get-Command -Name $Odin -CommandType Application -ErrorAction Stop | Select-Object -First 1
$OdinPath = $OdinCommand.Source
$OdinRoot = Split-Path -Parent $OdinPath
$OutputRoot = Join-Path $RepoRoot 'out'
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$SDL3 = Join-Path $OdinRoot 'vendor\sdl3\SDL3.dll'
if (-not (Test-Path -LiteralPath $SDL3 -PathType Leaf) -or (Get-Item -LiteralPath $SDL3).Length -lt 100000) {
    throw "A valid SDL3.dll was not found under '$OdinRoot\vendor\sdl3'."
}
Copy-Item -LiteralPath $SDL3 -Destination (Join-Path $OutputRoot 'SDL3.dll') -Force

$AccessKitSdk = & (Join-Path $AccessKitRoot 'tools\bootstrap.ps1') -CacheRoot (Join-Path $AlicornRoot '.deps\accesskit')
if ($LASTEXITCODE -ne 0 -or -not $AccessKitSdk -or -not $AccessKitSdk.CompilerArguments) {
    throw 'Could not prepare the pinned AccessKit SDK.'
}
$CompilerArguments = @("-collection:accesskit=$AccessKitRoot") + @($AccessKitSdk.CompilerArguments)
$AlicornCollection = "-collection:alicorn=$AlicornRoot"
$AliKitCollection = "-collection:alikit=$RepoRoot"

Push-Location $RepoRoot
try {
    & $OdinPath test palette_model '-define:ODIN_TEST_THREADS=1' "-out:$(Join-Path $OutputRoot 'palette_model_tests.exe')"
    if ($LASTEXITCODE -ne 0) { throw 'AliKit palette model tests failed.' }

    & $OdinPath test tree_model '-define:ODIN_TEST_THREADS=1' "-out:$(Join-Path $OutputRoot 'tree_model_tests.exe')"
    if ($LASTEXITCODE -ne 0) { throw 'AliKit tree model tests failed.' }

    $PaletteTestArgs = @(
        'test', 'command_palette',
        '-define:ODIN_TEST_THREADS=1',
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'command_palette_tests.exe')"
    ) + $CompilerArguments
    & $OdinPath @PaletteTestArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit retained command palette tests failed.' }

    $TreeTestArgs = @(
        'test', 'tree_view',
        '-define:ODIN_TEST_THREADS=1',
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'tree_view_tests.exe')"
    ) + $CompilerArguments
    & $OdinPath @TreeTestArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit retained Tree View tests failed.' }

    $ExampleArgs = @(
        'build', (Join-Path $RepoRoot 'examples\command_palette'),
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'command_palette_example.exe')"
    ) + $CompilerArguments
    & $OdinPath @ExampleArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit native example failed to compile.' }

    $TreeExampleArgs = @(
        'build', (Join-Path $RepoRoot 'examples\tree_view'),
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'tree_view_example.exe')"
    ) + $CompilerArguments
    & $OdinPath @TreeExampleArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit native Tree View example failed to compile.' }
} finally {
    Pop-Location
}
