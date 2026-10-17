$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Split-Path -Parent $PSScriptRoot)).Path
$taskRelease = Get-Content -LiteralPath (Join-Path $taskRoot 'game/content/release.json') -Raw | ConvertFrom-Json
$taskWindows = Join-Path $taskRoot 'output/windows'
$taskCurrent = (Resolve-Path -LiteralPath (Join-Path $taskWindows ('v' + $taskRelease.version))).Path
if (-not (Test-Path -LiteralPath (Join-Path $taskCurrent 'CoastalFoundation.exe'))) { throw 'Current executable is missing; refusing cleanup.' }
$taskTargets = @()
$taskTargets += Get-ChildItem -LiteralPath $taskWindows -Force | Where-Object { $_.FullName -ne $taskCurrent }
$taskTargets += Get-Item -LiteralPath (Join-Path $taskRoot 'art/source/history') -ErrorAction SilentlyContinue
$taskTargets += Get-ChildItem -LiteralPath (Join-Path $taskRoot 'art/source') -File | Where-Object { $_.Extension -match '^\.blend\d+$' }
$taskTargets += Get-Item -LiteralPath (Join-Path $taskRoot 'output/previews') -ErrorAction SilentlyContinue
$taskKeepVerification = @('windows-render','current-render-evidence.json','latest-test-result.json','latest-test.log','icon-report.json','icon-source.sha256','sword-clearance.json','walk-skirt.json','advanced-sword-clearance.json','advanced-walk-skirt.json','user-heroine-draft','user-heroine-anime-draft')
$taskVerification = Join-Path $taskRoot 'output/verification'
$taskTargets += Get-ChildItem -LiteralPath $taskVerification -Force | Where-Object { $_.Name -notin $taskKeepVerification }
$taskAcceptedFrames = @()
$taskEvidencePath = Join-Path $taskVerification 'current-render-evidence.json'
if (Test-Path -LiteralPath $taskEvidencePath) {
    $taskEvidence = Get-Content -LiteralPath $taskEvidencePath -Raw | ConvertFrom-Json
    $taskBuildState = Get-Content -LiteralPath (Join-Path $taskRoot 'output/build-cache.json') -Raw | ConvertFrom-Json
    if ($taskEvidence.release -eq $taskRelease.version -and $taskEvidence.game_key -eq $taskBuildState.game_key) {
        $taskAcceptedFrames = @($taskEvidence.files | ForEach-Object { ($_ -split '/')[0] } | Select-Object -Unique)
    }
}
foreach ($taskCaptureItem in (Get-ChildItem -LiteralPath (Join-Path $taskVerification 'windows-render') -Force)) {
    if ($taskCaptureItem.Name -in $taskAcceptedFrames) { continue }
    $taskTargets += $taskCaptureItem
}
$taskRemoved = @()
foreach ($taskItem in $taskTargets) {
    if ($null -eq $taskItem) { continue }
    $taskResolved = (Resolve-Path -LiteralPath $taskItem.FullName).Path
    $taskAllowed = @('output/windows','output/verification','output/previews','art/source') | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $taskRoot $_)) }
    $taskWithin = $false
    foreach ($taskBoundary in $taskAllowed) {
        if ($taskResolved -eq $taskBoundary -or $taskResolved.StartsWith($taskBoundary + '\', [StringComparison]::OrdinalIgnoreCase)) { $taskWithin = $true }
    }
    if (-not $taskWithin -or $taskResolved -eq $taskCurrent -or $taskResolved.StartsWith($taskCurrent + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe cleanup target: $taskResolved" }
    if (($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -and ($taskItem.Attributes -band [IO.FileAttributes]::Directory)) {
        # OneDrive cloud folders may have reparse attributes; resolved paths above
        # must still lie inside the explicitly named cleanup directories.
        $taskFinalPath = [IO.Path]::GetFullPath($taskResolved)
        if ($taskFinalPath -ne $taskResolved) { throw 'Unexpected resolved folder path.' }
    }
    Remove-Item -LiteralPath $taskResolved -Recurse -Force
    $taskRemoved += $taskResolved.Substring($taskRoot.Length + 1)
}
[pscustomobject]@{ CurrentRelease=$taskCurrent; Removed=$taskRemoved; Count=$taskRemoved.Count } | ConvertTo-Json -Depth 3
