$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot 'install-local-theme.ps1'
$ids = @(
    'wuthering-shorekeeper',
    'wuthering-changli',
    'onepiece-luffy-gear5',
    'onepiece-straw-hats'
)
foreach ($id in $ids) { & $installer -ExampleId $id }
Write-Host 'Anime theme color shells are ready. Run Switch Theme.cmd to select one.' -ForegroundColor Cyan

