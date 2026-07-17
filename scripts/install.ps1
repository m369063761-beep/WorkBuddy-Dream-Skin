[CmdletBinding()]
param(
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA 'WorkBuddyDreamSkin'),
    [switch]$NoLaunch,
    [switch]$NoShortcuts
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedSource = (Resolve-Path -LiteralPath $projectRoot).Path.TrimEnd('\')
$resolvedTarget = [IO.Path]::GetFullPath($InstallPath).TrimEnd('\')
if ($resolvedTarget -eq $resolvedSource) { throw 'The installer cannot use the source folder as its destination.' }
if (-not $resolvedTarget.StartsWith([IO.Path]::GetFullPath($env:LOCALAPPDATA), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'For safety, the installer destination must be inside the current user LOCALAPPDATA folder.'
}

New-Item -ItemType Directory -Path $resolvedTarget -Force | Out-Null
$directories = @('docs', 'scripts', 'src', 'theme-examples', 'themes', 'tests')
foreach ($directory in $directories) {
    $destination = Join-Path $resolvedTarget $directory
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination $destination -Recurse -Force
}

$rootFiles = @(
    'CHANGELOG.md', 'LICENSE', 'README.md', 'VERSION',
    'Start Dream Skin.cmd', 'Switch Theme.cmd', 'Restore WorkBuddy.cmd',
    'Install Anime Theme Shells.cmd', 'Theme Studio.cmd',
    'Install WorkBuddy Dream Skin.cmd', 'Uninstall WorkBuddy Dream Skin.cmd'
)
foreach ($file in $rootFiles) { Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $resolvedTarget $file) -Force }
New-Item -ItemType Directory -Path (Join-Path $resolvedTarget 'themes-local') -Force | Out-Null

if (-not $NoShortcuts) {
    $shell = New-Object -ComObject WScript.Shell
    $desktop = $shell.SpecialFolders('Desktop')
    $startMenuFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WorkBuddy Dream Skin'
    New-Item -ItemType Directory -Path $startMenuFolder -Force | Out-Null
    foreach ($shortcutPath in @((Join-Path $desktop 'WorkBuddy Dream Skin.lnk'), (Join-Path $startMenuFolder 'WorkBuddy Dream Skin.lnk'))) {
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = (Join-Path $resolvedTarget 'Theme Studio.cmd')
        $shortcut.WorkingDirectory = $resolvedTarget
        $shortcut.Description = 'WorkBuddy Dream Skin 主题中心'
        $shortcut.Save()
    }
    $uninstallShortcut = $shell.CreateShortcut((Join-Path $startMenuFolder '卸载 WorkBuddy Dream Skin.lnk'))
    $uninstallShortcut.TargetPath = (Join-Path $resolvedTarget 'Uninstall WorkBuddy Dream Skin.cmd')
    $uninstallShortcut.WorkingDirectory = $resolvedTarget
    $uninstallShortcut.Save()
}

Write-Host "Installed WorkBuddy Dream Skin to: $resolvedTarget" -ForegroundColor Green
if (-not $NoShortcuts) { Write-Host 'Desktop and Start Menu shortcuts were created.' -ForegroundColor Green }
if (-not $NoLaunch) { Start-Process -FilePath (Join-Path $resolvedTarget 'Theme Studio.cmd') | Out-Null }
