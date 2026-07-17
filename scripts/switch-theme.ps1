[CmdletBinding()]
param(
    [string]$ThemeId,
    [int]$Port = 19333,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

$themes = @(Get-WbdsThemes -ProjectRoot $projectRoot)
if (-not $themes.Count) { throw 'No themes were found.' }

if ($List) {
    $themes | Select-Object Id, Name, Kind, HasBackground, Description | Format-Table -AutoSize
    exit 0
}

if (-not $ThemeId) {
    Write-Host ''
    Write-Host 'WorkBuddy Dream Skin themes' -ForegroundColor Cyan
    for ($index = 0; $index -lt $themes.Count; $index++) {
        $status = if ($themes[$index].HasBackground) { 'ready' } else { 'image missing' }
        Write-Host ("[{0}] {1} - {2} ({3})" -f ($index + 1), $themes[$index].Name, $themes[$index].Description, $status)
    }
    $choice = Read-Host 'Choose a theme number'
    $number = 0
    if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $themes.Count) {
        throw 'Invalid theme number.'
    }
    $selected = $themes[$number - 1]
} else {
    $selected = $themes | Where-Object Id -eq $ThemeId | Select-Object -First 1
    if (-not $selected) { throw "Theme not found: $ThemeId" }
}

if (-not $selected.HasBackground) { throw "Theme background is missing: $($selected.Path)" }
$target = Get-WbdsTarget -Port $Port
if (-not $target) { throw "No Dream Skin WorkBuddy session was found on port $Port. Start Dream Skin first." }
$null = Set-WbdsTheme -WebSocketUrl $target.webSocketDebuggerUrl -ThemePath $selected.Path
Save-WbdsThemeState -ProjectRoot $projectRoot -ThemeId $selected.Id -ThemePath $selected.Path
Write-Host "Theme switched: $($selected.Name)" -ForegroundColor Green

