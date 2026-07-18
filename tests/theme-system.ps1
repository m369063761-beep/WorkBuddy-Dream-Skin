$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

$themes = @(Get-WbdsThemes -ProjectRoot $projectRoot)
if (-not ($themes.Id -contains 'dream-glass')) { throw 'dream-glass theme was not discovered.' }
if (-not ($themes.Id -contains 'sakura-night')) { throw 'sakura-night theme was not discovered.' }
if (($themes.Id | Sort-Object -Unique).Count -ne $themes.Count) { throw 'Theme IDs must be unique.' }

$dream = $themes | Where-Object Id -eq 'dream-glass' | Select-Object -First 1
if (-not $dream.HasBackground) { throw 'dream-glass should work without an image.' }
$dreamCss = Get-WbdsThemeCss -ThemePath $dream.Path
if ($dreamCss.Css -match '__WBDS_[A-Z_]+__') { throw 'Theme CSS contains an unresolved token.' }
if ($dreamCss.Css -notmatch '--wbds-accent: #9b83ff') { throw 'Theme palette was not injected into CSS.' }
$sakura = $themes | Where-Object Id -eq 'sakura-night' | Select-Object -First 1
$sakuraCss = Get-WbdsThemeCss -ThemePath $sakura.Path
if ($sakuraCss.Scheme -ne 'light') { throw 'Sakura Night should use the light color scheme.' }
Write-Host "PASS: discovered $($themes.Count) theme(s)" -ForegroundColor Green
