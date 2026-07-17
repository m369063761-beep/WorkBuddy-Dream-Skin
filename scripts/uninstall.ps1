[CmdletBinding()]
param([switch]$KeepThemes)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'WorkBuddyDreamSkin')).TrimEnd('\')
$actualRoot = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
if ($actualRoot -ne $expectedRoot) {
    throw "For safety, uninstall only runs from the standard installation folder: $expectedRoot"
}

$shell = New-Object -ComObject WScript.Shell
$desktopShortcut = Join-Path $shell.SpecialFolders('Desktop') 'WorkBuddy Dream Skin.lnk'
$startMenuFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WorkBuddy Dream Skin'
if (Test-Path -LiteralPath $desktopShortcut) { Remove-Item -LiteralPath $desktopShortcut -Force }
if (Test-Path -LiteralPath $startMenuFolder) { Remove-Item -LiteralPath $startMenuFolder -Recurse -Force }

$backup = $null
if ($KeepThemes -and (Test-Path -LiteralPath (Join-Path $actualRoot 'themes-local'))) {
    $backup = Join-Path $env:TEMP ("wbds-themes-{0}" -f [Guid]::NewGuid().ToString('N'))
    Move-Item -LiteralPath (Join-Path $actualRoot 'themes-local') -Destination $backup
}

$cleanup = Join-Path $env:TEMP ("wbds-uninstall-{0}.cmd" -f [Guid]::NewGuid().ToString('N'))
$lines = @('@echo off', 'timeout /t 2 /nobreak >nul', ('rmdir /s /q "{0}"' -f $actualRoot))
if ($backup) {
    $restore = Join-Path $env:LOCALAPPDATA 'WorkBuddyDreamSkin-Themes-Backup'
    $lines += ('move /y "{0}" "{1}" >nul' -f $backup, $restore)
}
$lines += 'del "%~f0"'
[IO.File]::WriteAllLines($cleanup, $lines, [Text.Encoding]::ASCII)
Start-Process -FilePath $cleanup -WindowStyle Hidden | Out-Null
Write-Host 'Uninstall scheduled. This window will close and the installation folder will be removed.' -ForegroundColor Green

