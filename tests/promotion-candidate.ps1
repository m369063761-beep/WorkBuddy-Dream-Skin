$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $projectRoot 'scripts\theme-studio.ps1') -SmokeTest
if ($LASTEXITCODE -ne 0) { throw 'Theme Studio smoke test failed.' }

$testRoot = Join-Path $projectRoot 'work\promotion-test'
$testThemeDirectory = Join-Path $testRoot 'base-theme'
$customDirectory = Join-Path $projectRoot 'themes-local\custom-promotion-test-source'
$installTarget = Join-Path $env:LOCALAPPDATA ("WorkBuddyDreamSkin-Test-{0}" -f $PID)
try {
    New-Item -ItemType Directory -Path $testThemeDirectory -Force | Out-Null
    $sourceConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'themes\dream\theme.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $sourceConfig.id = 'promotion-test-source'
    $sourceConfig.name = 'Promotion Test Source'
    $sourceConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $testThemeDirectory 'theme.json') -Encoding UTF8
    $gifPath = Join-Path $testRoot 'one-pixel.gif'
    [IO.File]::WriteAllBytes($gifPath, [Convert]::FromBase64String('R0lGODlhAQABAAAAACw='))

    $custom = New-WbdsCustomTheme -ProjectRoot $projectRoot -BaseThemePath (Join-Path $testThemeDirectory 'theme.json') -BackgroundPath $gifPath
    if (-not (Test-Path -LiteralPath $custom.ImagePath -PathType Leaf)) { throw 'Custom image was not copied.' }
    $discovered = Get-WbdsThemes -ProjectRoot $projectRoot | Where-Object Id -eq $custom.Id
    if (-not $discovered -or -not $discovered.HasBackground) { throw 'Custom theme was not discovered as ready.' }

    & (Join-Path $projectRoot 'scripts\install.ps1') -InstallPath $installTarget -NoLaunch -NoShortcuts
    $marker = Join-Path $installTarget 'themes-local\preserve-me.txt'
    Set-Content -LiteralPath $marker -Value 'keep' -Encoding ASCII
    & (Join-Path $projectRoot 'scripts\install.ps1') -InstallPath $installTarget -NoLaunch -NoShortcuts
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'Installer update did not preserve local themes.' }
    if (-not (Test-Path -LiteralPath (Join-Path $installTarget 'Theme Studio.cmd') -PathType Leaf)) { throw 'Installed Theme Studio entry point is missing.' }
    Write-Host 'PASS: custom image, install, and update-preservation tests passed.' -ForegroundColor Green
} finally {
    if (Test-Path -LiteralPath $customDirectory) { Remove-Item -LiteralPath $customDirectory -Recurse -Force }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    $localAppDataRoot = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
    $resolvedTarget = [IO.Path]::GetFullPath($installTarget)
    if ($resolvedTarget.StartsWith($localAppDataRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTarget)) {
        Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
    }
}
