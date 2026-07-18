$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $projectRoot 'work\customer-pack-test'
$extractRoot = Join-Path $testRoot 'extract'
$installTarget = Join-Path $env:LOCALAPPDATA ("WorkBuddyDreamSkin-CustomerTest-{0}" -f $PID)

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $imagePath = Join-Path $testRoot 'customer.png'
    [IO.File]::WriteAllBytes($imagePath, [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
    $result = & (Join-Path $projectRoot 'scripts\build-customer-pack.ps1') `
        -ClientName '测试客户' `
        -ThemeName '测试客户 · 海蓝主题' `
        -BackgroundPath $imagePath `
        -BaseThemePath (Join-Path $projectRoot 'themes\dream\theme.json') `
        -OutputDirectory $testRoot `
        -Version 'test'

    if (-not (Test-Path -LiteralPath $result.Archive -PathType Leaf)) { throw 'Customer archive was not created.' }
    if (-not (Test-Path -LiteralPath $result.HashPath -PathType Leaf)) { throw 'Customer SHA256 file was not created.' }
    Expand-Archive -LiteralPath $result.Archive -DestinationPath $extractRoot -Force
    $packageRoot = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
    if (-not $packageRoot) { throw 'Customer archive has no package root.' }
    if (Test-Path -LiteralPath (Join-Path $packageRoot.FullName '制作客户定制包.cmd')) { throw 'Customer archive leaked the seller entry point.' }
    if (Test-Path -LiteralPath (Join-Path $packageRoot.FullName 'scripts\customer-pack-studio.ps1')) { throw 'Customer archive leaked the seller studio.' }

    $defaultThemeId = (Get-Content -LiteralPath (Join-Path $packageRoot.FullName 'customer-default-theme.txt') -Raw -Encoding ASCII).Trim()
    if ($defaultThemeId -ne $result.ThemeId) { throw 'Customer default theme id is incorrect.' }
    $themePath = Join-Path $packageRoot.FullName "themes\$defaultThemeId\theme.json"
    if (-not (Test-Path -LiteralPath $themePath -PathType Leaf)) { throw 'Customer theme configuration is missing.' }
    Import-Module (Join-Path $packageRoot.FullName 'src\WorkBuddyDreamSkin.psm1') -Force
    $themeCss = Get-WbdsThemeCss -ThemePath $themePath
    if ($themeCss.Css -match '__WBDS_[A-Z_]+__') { throw 'Customer theme contains an unresolved CSS token.' }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $packageRoot.FullName 'scripts\theme-studio.ps1') -SmokeTest
    if ($LASTEXITCODE -ne 0) { throw 'Customer Theme Studio smoke test failed.' }
    & (Join-Path $packageRoot.FullName 'scripts\install.ps1') -InstallPath $installTarget -NoLaunch -NoShortcuts
    if (-not (Test-Path -LiteralPath (Join-Path $installTarget "themes\$defaultThemeId\theme.json") -PathType Leaf)) { throw 'Installed customer theme is missing.' }
    Write-Host 'PASS: private customer ZIP, preselection, theme injection, and installation tests passed.' -ForegroundColor Green
} finally {
    $resolvedProjectWork = [IO.Path]::GetFullPath((Join-Path $projectRoot 'work')).TrimEnd('\')
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($resolvedProjectWork, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
    $resolvedLocalAppData = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
    $resolvedInstallTarget = [IO.Path]::GetFullPath($installTarget)
    if ($resolvedInstallTarget.StartsWith($resolvedLocalAppData, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedInstallTarget)) {
        Remove-Item -LiteralPath $resolvedInstallTarget -Recurse -Force
    }
}
