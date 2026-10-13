$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskRelease = Get-Content -LiteralPath (Join-Path $taskProjectRoot 'game/content/release.json') -Raw | ConvertFrom-Json
$taskBuilderTarget = Join-Path $taskProjectRoot ('output/windows/v' + $taskRelease.version + '/MapBuilder.exe')
Start-Process -FilePath $taskBuilderTarget -WorkingDirectory (Split-Path -Parent $taskBuilderTarget)
