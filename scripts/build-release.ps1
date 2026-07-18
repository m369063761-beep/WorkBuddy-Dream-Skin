[CmdletBinding()]
param([string]$Version = '0.2.1')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $projectRoot 'dist'
$staging = Join-Path $dist 'WorkBuddy-Dream-Skin'
if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

$directories = @('docs', 'scripts', 'src', 'theme-examples', 'themes', 'tests')
foreach ($directory in $directories) { Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination (Join-Path $staging $directory) -Recurse -Force }
$files = @(
    'CHANGELOG.md', 'LICENSE', 'README.md', 'VERSION',
    'Start Dream Skin.cmd', 'Switch Theme.cmd', 'Restore WorkBuddy.cmd',
    'Install Anime Theme Shells.cmd', 'Theme Studio.cmd',
    'Install WorkBuddy Dream Skin.cmd', 'Uninstall WorkBuddy Dream Skin.cmd',
    '制作客户定制包.cmd'
)
foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $staging $file) -Force }

$archive = Join-Path $dist ("WorkBuddy-Dream-Skin-Windows-v{0}.zip" -f $Version)
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
Compress-Archive -LiteralPath $staging -DestinationPath $archive -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
Set-Content -LiteralPath "$archive.sha256" -Value "$hash  $([IO.Path]::GetFileName($archive))" -Encoding ASCII
Remove-Item -LiteralPath $staging -Recurse -Force
Write-Host "Built: $archive" -ForegroundColor Green
Write-Host "SHA256: $hash"
