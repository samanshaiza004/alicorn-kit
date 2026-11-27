param(
    [string]$Odin = 'odin',
    [string]$AlicornRoot = '',
    [string]$ConsumerRoot = '',
    [switch]$SkipSmoke
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$FixtureRoot = Join-Path $RepoRoot 'tests\external_consumer'
$Lock = Get-Content -LiteralPath (Join-Path $RepoRoot 'dependencies.lock.json') -Raw | ConvertFrom-Json

if (-not $AlicornRoot) { $AlicornRoot = Join-Path $RepoRoot 'alicorn' }
$AlicornRoot = (Resolve-Path -LiteralPath $AlicornRoot).Path
if (-not $ConsumerRoot) {
    $ConsumerRoot = Join-Path ([IO.Path]::GetTempPath()) 'alikit-external-consumer'
} elseif (-not [IO.Path]::IsPathRooted($ConsumerRoot)) {
    $ConsumerRoot = Join-Path (Get-Location).Path $ConsumerRoot
}
$ConsumerRoot = [IO.Path]::GetFullPath($ConsumerRoot)

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
$SDL3 = Join-Path $OdinRoot 'vendor\sdl3\SDL3.dll'
if (-not (Test-Path -LiteralPath $SDL3 -PathType Leaf) -or (Get-Item -LiteralPath $SDL3).Length -lt 100000) {
    throw "A valid SDL3.dll was not found under '$OdinRoot\vendor\sdl3'."
}

$AccessKitSdk = & (Join-Path $AccessKitRoot 'tools\bootstrap.ps1') -CacheRoot (Join-Path $AlicornRoot '.deps\accesskit')
if ($LASTEXITCODE -ne 0 -or -not $AccessKitSdk -or -not $AccessKitSdk.CompilerArguments) {
    throw 'Could not prepare the pinned AccessKit SDK.'
}
$CompilerArguments = @("-collection:accesskit=$AccessKitRoot") + @($AccessKitSdk.CompilerArguments)
$AlicornCollection = "-collection:alicorn=$AlicornRoot"
$AliKitCollection = "-collection:alikit=$RepoRoot"

function Read-Text([string]$Path) {
    return [IO.File]::ReadAllText($Path)
}

function Write-Text([string]$Path, [string]$Text) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Get-SourceImports([string]$Path) {
    $imports = @()
    foreach ($line in (Read-Text $Path) -split "`r?`n") {
        if ($line -match '^import\s+(?:[A-Za-z_][A-Za-z0-9_]*\s+)?"([^"]+)"') {
            $imports += $Matches[1]
        }
    }
    return $imports
}

function Assert-Manifest {
    $manifestPath = Join-Path $RepoRoot 'components.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    $validation = $manifest.validation
    foreach ($command in @($validation.native, $validation.captures, $validation.externalConsumer)) {
        if ($command -match '^\./([^\s]+)') {
            $script = Join-Path $RepoRoot ($Matches[1] -replace '/', '\')
            if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
                $errors.Add("validation command references missing script: $($Matches[1])")
            }
        }
    }

    $entries = @($manifest.components) + @($manifest.supportingPackages)
    $componentIds = @($manifest.components | ForEach-Object { $_.id })
    $coveredPackages = @()
    foreach ($entry in $entries) {
        $files = @()
        $files += @($entry.source)
        $files += @($entry.tests)
        if ($entry.example) { $files += $entry.example }
        if ($entry.capture) { $files += $entry.capture }
        if ($entry.partExamples) { $files += @($entry.partExamples) }
        foreach ($relative in $files) {
            if (-not $relative) { continue }
            if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relative) -PathType Leaf)) {
                $errors.Add("$($entry.id): declared file is missing: $relative")
            }
        }

        $declared = @()
        if ($entry.PSObject.Properties.Name -contains 'dependencies') { $declared = @($entry.dependencies) }
        $actual = @()
        foreach ($relative in @($entry.source)) {
            foreach ($import in (Get-SourceImports (Join-Path $RepoRoot $relative))) {
                if ($import -match '^(alikit|alicorn):') { $actual += $import }
            }
        }
        $actual = $actual | Sort-Object -Unique
        foreach ($import in $actual) {
            if ($import -notin $declared) {
                $errors.Add("$($entry.id): source imports '$import' but dependencies does not declare it")
            }
        }
        foreach ($import in $declared) {
            if ($import -notin $actual) {
                $warnings.Add("$($entry.id): declares '$import' but no declared source imports it")
            }
        }

        if ($entry.package -match '^alikit:([^/]+)$') {
            $coveredPackages += $Matches[1]
            if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $Matches[1]) -PathType Container)) {
                $errors.Add("$($entry.id): package directory is missing: $($Matches[1])")
            }
        }

        $needsCopy = $entry.id -in $componentIds
        if ($entry.PSObject.Properties.Name -contains 'copy') {
            foreach ($relative in @($entry.copy.sources)) {
                if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $relative) -PathType Leaf)) {
                    $errors.Add("$($entry.id): copy source is missing: $relative")
                }
            }
            foreach ($source in @($entry.source)) {
                $sourceText = Read-Text (Join-Path $RepoRoot $source)
                foreach ($rewrite in $entry.copy.importRewrites.PSObject.Properties) {
                    if ($sourceText -notmatch [regex]::Escape("`"$($rewrite.Name)`"")) {
                        $errors.Add("$($entry.id): copy rewrite names an import $source no longer uses: $($rewrite.Name)")
                    }
                }
            }
        } elseif ($needsCopy) {
            $errors.Add("$($entry.id): components.json must declare a copy recipe (sources and import rewrites)")
        }
    }

    foreach ($directory in Get-ChildItem -LiteralPath $RepoRoot -Directory) {
        if ($directory.Name -in @('.git', '.github', 'alicorn', 'docs', 'examples', 'out', 'tests', 'tools', 'website')) { continue }
        if (-not (Get-ChildItem -LiteralPath $directory.FullName -Filter '*.odin' -File)) { continue }
        if ($directory.Name -notin $coveredPackages) {
            $warnings.Add("package '$($directory.Name)' has Odin source but no components.json entry")
        }
    }

    # The copy fixture audits every current component source-copy recipe.
    return [pscustomobject]@{ Errors = $errors; Warnings = $warnings; Manifest = $manifest }
}

function New-Consumer([object]$Manifest) {
    if (Test-Path -LiteralPath $ConsumerRoot) {
        Remove-Item -LiteralPath $ConsumerRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $ConsumerRoot, (Join-Path $ConsumerRoot 'bin') | Out-Null

    $Path1 = Join-Path $ConsumerRoot 'path1_packages'
    $Path2 = Join-Path $ConsumerRoot 'path2_copy'
    Copy-Item -LiteralPath (Join-Path $FixtureRoot 'path1_packages') -Destination $Path1 -Recurse
    Copy-Item -LiteralPath (Join-Path $FixtureRoot 'path2_copy') -Destination $Path2 -Recurse

    # The copied-source fixture exercises every declared component recipe.
    # Shared dependencies are copied once and each package's rewrites are
    # applied to the full source closure.
    $copyEntries = @($Manifest.components | Where-Object { $_.copy })
    if ($copyEntries.Count -ne $Manifest.components.Count) {
        throw 'Every catalog component must declare a source-copy recipe.'
    }
    $copySources = @{}
    $rewriteMap = @{}
    foreach ($entry in $copyEntries) {
        if (-not $entry.copy) { throw "$($entry.id) has no copy recipe in components.json." }
        foreach ($relative in @($entry.copy.sources)) { $copySources[$relative] = $true }
        foreach ($rewrite in $entry.copy.importRewrites.PSObject.Properties) {
            if ($rewriteMap.ContainsKey($rewrite.Name) -and $rewriteMap[$rewrite.Name] -cne $rewrite.Value) {
                throw "Conflicting copy rewrites for '$($rewrite.Name)'."
            }
            $rewriteMap[$rewrite.Name] = $rewrite.Value
        }
    }
    $Vendor = Join-Path $Path2 'vendor'
    $copiedFiles = @()
    foreach ($relative in $copySources.Keys) {
        $package = Split-Path -Leaf (Split-Path -Parent $relative)
        $fileName = Split-Path -Leaf $relative
        $destinationDirectory = Join-Path $Vendor $package
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
        $destination = Join-Path $destinationDirectory $fileName
        Copy-Item -LiteralPath (Join-Path $RepoRoot $relative) -Destination $destination
        $copiedFiles += $destination
    }

    # A copy is application code: the intra-AliKit imports become local package
    # imports, so no `alikit` collection is needed.
    $applied = @{}
    foreach ($name in $rewriteMap.Keys) {
        $applied[$name] = $false
    }
    foreach ($file in $copiedFiles) {
        $text = Read-Text $file
        foreach ($name in $rewriteMap.Keys) {
            $from = "`"$name`""
            $to = "`"$($rewriteMap[$name])`""
            if ($text.Contains($from)) {
                $text = $text.Replace($from, $to)
                $applied[$name] = $true
            }
        }
        Write-Text $file $text
        foreach ($import in (Get-SourceImports $file)) {
            if ($import -match '^alikit:') {
                throw "Copied $file still imports '$import'; the copy would require the alikit collection."
            }
        }
    }
    foreach ($name in $applied.Keys) {
        if (-not $applied[$name]) {
            throw "components.json declares a copy rewrite for '$name' but no copied source contains it."
        }
    }

    Copy-Item -LiteralPath $SDL3 -Destination (Join-Path $ConsumerRoot 'bin\SDL3.dll') -Force

    $notes = @"
# Generated external consumer

Generated by `tools/validate_external_consumer.ps1` at $(Get-Date -Format o).
This directory is outside the AliKit repository build; it is recreated on every run.

## Path 1: import packages (collection)

    odin build path1_packages -collection:alicorn=$AlicornRoot -collection:alikit=$RepoRoot -out:bin/external_consumer_path1.exe
    bin/external_consumer_path1.exe --smoke

Imports `alikit:dialog`, `alikit:menu`, `alikit:radio_group`, `alikit:progress`,
`alikit:notices`, and `alikit:selection`. Use both collections; the `alikit`
collection points at the AliKit checkout. The pinned AccessKit compiler
arguments are added by the harness exactly as `tools/test.ps1` does.

## Path 2: copy source (no alikit collection)

    odin build path2_copy -collection:alicorn=$AlicornRoot -out:bin/external_consumer_path2.exe
    bin/external_consumer_path2.exe --smoke

`vendor/` contains the declared source closures for all 14 catalog components,
including shared dependencies such as `selection`, `theme_contract`,
`palette_model`, `palette_parts`, `tree_model`, and `table_core`. Every copied
component imports its local sibling packages; no AliKit collection is present.
Keep the vendor directory together.

## Gotchas recorded by this run

- A collection import is the supported package path; source-copy consumers must
  copy the declared dependency files too and rewrite the intra-AliKit imports.
- SDL3.dll must sit beside the executable (the harness copies it to bin/).
- The AccessKit static SDK collection and linker flags are required by Alicorn's
  native SDL_GPU host at the pinned revision.
"@
    Write-Text (Join-Path $ConsumerRoot 'BUILD_NOTES.md') $notes
    return [pscustomobject]@{ Path1 = $Path1; Path2 = $Path2; Notes = (Join-Path $ConsumerRoot 'BUILD_NOTES.md') }
}

function Build([string]$Name, [string]$Source, [string]$Output, [string[]]$Collections) {
    $arguments = @('build', $Source) + $Collections + @("-out:$Output") + $CompilerArguments
    Write-Host "build $Name"
    Write-Host ("  odin " + ($arguments -join ' '))
    & $OdinPath @arguments
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $Name." }
}

function Invoke-Smoke([string]$Name, [string]$Executable) {
    $stdout = Join-Path $ConsumerRoot "$Name.smoke.stdout.log"
    $stderr = Join-Path $ConsumerRoot "$Name.smoke.stderr.log"
    if (Test-Path -LiteralPath $stdout) { Remove-Item -LiteralPath $stdout -Force }
    if (Test-Path -LiteralPath $stderr) { Remove-Item -LiteralPath $stderr -Force }
    $process = Start-Process -FilePath $Executable -ArgumentList '--smoke' `
        -WorkingDirectory $ConsumerRoot -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $output = if (Test-Path -LiteralPath $stdout) { Read-Text $stdout } else { '' }
    $errorOutput = if (Test-Path -LiteralPath $stderr) { Read-Text $stderr } else { '' }
    if ($process.ExitCode -ne 0) {
        throw "$Name smoke exited $($process.ExitCode).`nSTDOUT:`n$output`nSTDERR:`n$errorOutput"
    }
    if ($output -notmatch 'SDL application PASS') {
        throw "$Name smoke did not report the native host PASS.`nSTDOUT:`n$output`nSTDERR:`n$errorOutput"
    }
    if ($output -notmatch 'idle true') {
        throw "$Name smoke did not report the application idle line.`nSTDOUT:`n$output`nSTDERR:`n$errorOutput"
    }
    if ($output -match 'application_stabilization_limit_hits (\d+)' -and [int]$Matches[1] -ne 0) {
        throw "$Name smoke hit the stabilization limit; the description never settled.`nSTDOUT:`n$output"
    }
    if ($output -match 'application_build_samples (\d+)' -and [int]$Matches[1] -gt 3) {
        throw "$Name smoke rebuilt the application $($Matches[1]) times; expected a settled description."
    }
    # A first-frame runtime notice (the toast) may need one stabilization
    # rebuild. More than that means the description kept invalidating itself.
    if ($output -match 'application_stabilization_rebuilds (\d+)' -and [int]$Matches[1] -gt 1) {
        throw "$Name smoke kept rebuilding after the first description.`nSTDOUT:`n$output"
    }
    if ($output -match 'idle_after_last_submit_ns (\d+)' -and [int64]$Matches[1] -le 0) {
        throw "$Name smoke did not reach an idle interval."
    }
    $appLine = ($output -split "`r?`n" | Where-Object { $_ -match "${Name}_smoke" } | Select-Object -First 1)
    Write-Host "  $appLine"
    Write-Host "  SDL application PASS, idle true"
    return $appLine
}

$manifestAudit = Assert-Manifest
foreach ($warning in $manifestAudit.Warnings) { Write-Warning "manifest: $warning" }
if ($manifestAudit.Errors.Count -gt 0) {
    throw ("components.json audit failed:`n - " + ($manifestAudit.Errors -join "`n - "))
}

$consumer = New-Consumer $manifestAudit.Manifest
$path1Exe = Join-Path $ConsumerRoot 'bin\external_consumer_path1.exe'
$path2Exe = Join-Path $ConsumerRoot 'bin\external_consumer_path2.exe'

Push-Location $ConsumerRoot
try {
    Build 'path1 packages' $consumer.Path1 $path1Exe @($AlicornCollection, $AliKitCollection)
    Build 'path2 copied source' $consumer.Path2 $path2Exe @($AlicornCollection)

    if (-not $SkipSmoke) {
        Write-Host 'smoke path1'
        Invoke-Smoke 'external_consumer_path1' $path1Exe | Out-Null
        Write-Host 'smoke path2'
        Invoke-Smoke 'external_consumer_path2' $path2Exe | Out-Null
    }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host "External consumer validation passed."
Write-Host "  consumer: $ConsumerRoot"
Write-Host "  notes:    $($consumer.Notes)"
Write-Host "  path 1:   -collection:alicorn=$AlicornRoot -collection:alikit=$RepoRoot"
Write-Host "  path 2:   -collection:alicorn=$AlicornRoot (copied sources only)"
