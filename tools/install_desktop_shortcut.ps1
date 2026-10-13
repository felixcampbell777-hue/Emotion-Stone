$ErrorActionPreference = 'Stop'
$taskGameDirectory = $PSScriptRoot
$taskLauncherArguments = ''
if (-not (Test-Path -LiteralPath (Join-Path $taskGameDirectory 'CoastalFoundation.exe'))) {
    $taskProjectRoot = Split-Path -Parent $PSScriptRoot
    $taskRelease = Get-Content -LiteralPath (Join-Path $taskProjectRoot 'game/content/release.json') -Raw | ConvertFrom-Json
    $taskGameDirectory = Join-Path $taskProjectRoot ('output/windows/v' + $taskRelease.version)
}
$taskGameTarget = (Resolve-Path -LiteralPath (Join-Path $taskGameDirectory 'CoastalFoundation.exe')).Path
$taskGameIcon = (Resolve-Path -LiteralPath (Join-Path $taskGameDirectory 'CoastalFoundation-v3.ico')).Path
if ($taskProjectRoot) {
    $taskGameTarget = (Get-Command powershell.exe).Source
    $taskLauncherArguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $taskProjectRoot 'tools/launch_game.ps1') + '"'
}
$taskDesktopPath = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($taskDesktopPath)) { throw 'Windows desktop folder not found.' }
$taskShortcutPath = Join-Path $taskDesktopPath 'Coastal Foundation.lnk'
$taskShortcutShell = New-Object -ComObject WScript.Shell
if (Test-Path -LiteralPath $taskShortcutPath) {
    $taskExistingShortcut = $taskShortcutShell.CreateShortcut($taskShortcutPath)
    if ($taskExistingShortcut.TargetPath -ne $taskGameTarget -and $taskExistingShortcut.Description -notlike 'Coastal Foundation*') {
        $taskShortcutPath = Join-Path $taskDesktopPath 'Coastal Foundation Game.lnk'
        if (Test-Path -LiteralPath $taskShortcutPath) {
            $taskExistingShortcut = $taskShortcutShell.CreateShortcut($taskShortcutPath)
            if ($taskExistingShortcut.TargetPath -ne $taskGameTarget) { throw 'Shortcut names already belong to other targets.' }
        }
    }
}
$taskShortcut = $taskShortcutShell.CreateShortcut($taskShortcutPath)
$taskShortcut.TargetPath = $taskGameTarget
$taskShortcut.Arguments = $taskLauncherArguments
$taskShortcut.WorkingDirectory = $taskGameDirectory
$taskShortcut.IconLocation = "$taskGameIcon,0"
$taskShortcut.Description = 'Coastal Foundation - exploration, oversized sword combat, and timed parries'
$taskShortcut.WindowStyle = 1
$taskShortcut.Save()
$taskSavedShortcut = $taskShortcutShell.CreateShortcut($taskShortcutPath)
if ($taskSavedShortcut.TargetPath -ne $taskGameTarget -or $taskSavedShortcut.Arguments -ne $taskLauncherArguments -or $taskSavedShortcut.IconLocation -ne "$taskGameIcon,0") { throw 'Shortcut verification failed.' }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CoastalShortcutRefresh {
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    public static extern void SHChangeNotify(uint eventId, uint flags, string item1, string item2);
}
'@
[CoastalShortcutRefresh]::SHChangeNotify(0x2000,0x5,$taskShortcutPath,$null)
[pscustomobject]@{ Shortcut=$taskShortcutPath; Target=$taskGameTarget; Icon=$taskSavedShortcut.IconLocation } | ConvertTo-Json

$taskBuilderTarget = Join-Path $taskGameDirectory 'MapBuilder.exe'
$taskBuilderArguments = ''
if ($taskProjectRoot) {
    $taskBuilderTarget = (Get-Command powershell.exe).Source
    $taskBuilderArguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + (Join-Path $taskProjectRoot 'tools/launch_builder.ps1') + '"'
}
$taskBuilderShortcutPath = Join-Path $taskDesktopPath 'Coastal Map Builder.lnk'
$taskBuilderShortcut = $taskShortcutShell.CreateShortcut($taskBuilderShortcutPath)
$taskBuilderShortcut.TargetPath = $taskBuilderTarget
$taskBuilderShortcut.Arguments = $taskBuilderArguments
$taskBuilderShortcut.WorkingDirectory = $taskGameDirectory
$taskBuilderShortcut.IconLocation = "$taskGameIcon,0"
$taskBuilderShortcut.Description = 'Coastal Map Builder - offline drag and drop world editor'
$taskBuilderShortcut.Save()
Write-Output "Map Builder shortcut: $taskBuilderShortcutPath"
