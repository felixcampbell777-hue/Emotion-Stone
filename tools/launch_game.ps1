$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskRelease = Get-Content -LiteralPath (Join-Path $taskProjectRoot 'game/content/release.json') -Raw | ConvertFrom-Json
$taskGameTarget = Join-Path $taskProjectRoot ('output/windows/v' + $taskRelease.version + '/CoastalFoundation.exe')
Start-Process -FilePath $taskGameTarget -WorkingDirectory (Split-Path -Parent $taskGameTarget)
