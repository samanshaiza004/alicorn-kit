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

    $PartsTestArgs = @(
        'test', 'palette_parts',
        '-define:ODIN_TEST_THREADS=1',
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'palette_parts_tests.exe')"
    ) + $CompilerArguments
    & $OdinPath @PartsTestArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit parts-based palette tests failed.' }

    $IconPickerTestArgs = @(
        'test', 'icon_picker',
        '-define:ODIN_TEST_THREADS=1',
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'icon_picker_tests.exe')"
    ) + $CompilerArguments
    & $OdinPath @IconPickerTestArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit icon picker tests failed.' }

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

    $IconPickerExampleArgs = @(
        'build', (Join-Path $RepoRoot 'examples\icon_picker'),
        $AlicornCollection,
        $AliKitCollection,
        "-out:$(Join-Path $OutputRoot 'icon_picker_example.exe')"
    ) + $CompilerArguments
    & $OdinPath @IconPickerExampleArgs
    if ($LASTEXITCODE -ne 0) { throw 'AliKit native icon picker example failed to compile.' }

    # Prove the composite is copyable source: copy the package beside a tiny
    # consumer and compile with only the Alicorn collection (no `alikit`
    # collection or repository-relative package topology).
    $CopyableRoot = Join-Path $OutputRoot 'copyable'
    if (Test-Path -LiteralPath $CopyableRoot) { Remove-Item -LiteralPath $CopyableRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $CopyableRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'icon_picker') -Destination (Join-Path $CopyableRoot 'icon_picker') -Recurse
    $CopyableConsumer = @'
package main

import alicorn "alicorn:runtime"
import ui "alicorn:ui"
import picker "./icon_picker"

App :: struct {
	state: picker.State,
	choices: [2]picker.Choice,
}

render :: proc(app: ^App, ctx: ^ui.UI) {
	event := picker.picker(ctx, &app.state, app.choices[:],
		picker.Options{accessible_label="Copied icons"}, key=alicorn.key_string("copied-picker"), instance_id=1)
	if event.kind == .Activated { app.state.selected_key = event.key }
}

main :: proc() {
	app := App{choices={picker.Choice{key=1, label="One", icon=.Search}, picker.Choice{key=2, label="Two", icon=.File}}}
	if !picker.init(&app.state) { return }
	defer picker.destroy(&app.state)
	ui.run(&app, render, title="copyable icon picker", smoke=true)
}
'@
    Set-Content -LiteralPath (Join-Path $CopyableRoot 'main.odin') -Value $CopyableConsumer -NoNewline
    $CopyableArgs = @(
        'build', $CopyableRoot,
        $AlicornCollection,
        "-out:$(Join-Path $OutputRoot 'icon_picker_copyable.exe')"
    ) + $CompilerArguments
    & $OdinPath @CopyableArgs
    if ($LASTEXITCODE -ne 0) { throw 'The copied icon picker source failed to build without the AliKit collection.' }
} finally {
    Pop-Location
}
