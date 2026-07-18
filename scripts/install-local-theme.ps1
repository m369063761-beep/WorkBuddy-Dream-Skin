[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ExampleId,
    [string]$BackgroundPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$exampleDirectory = Join-Path $projectRoot ("theme-examples\{0}" -f $ExampleId)
$exampleConfig = Join-Path $exampleDirectory 'theme.example.json'
if (-not (Test-Path -LiteralPath $exampleConfig -PathType Leaf)) { throw "Theme example not found: $ExampleId" }
if ($BackgroundPath -and -not (Test-Path -LiteralPath $BackgroundPath -PathType Leaf)) { throw "Background not found: $BackgroundPath" }

$targetDirectory = Join-Path $projectRoot ("themes-local\{0}" -f $ExampleId)
New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
Copy-Item -LiteralPath $exampleConfig -Destination (Join-Path $targetDirectory 'theme.json') -Force

$configPath = Join-Path $targetDirectory 'theme.json'
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$config.backgroundImage = ''
if ($BackgroundPath) {
    $extension = [IO.Path]::GetExtension($BackgroundPath).ToLowerInvariant()
    $targetImage = Join-Path $targetDirectory ("background{0}" -f $extension)
    Copy-Item -LiteralPath $BackgroundPath -Destination $targetImage -Force
    $config.backgroundImage = [IO.Path]::GetFileName($targetImage)
} else {
    $packagedImage = Get-ChildItem -LiteralPath $exampleDirectory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.jpg', '.jpeg', '.png', '.webp', '.gif') } |
        Select-Object -First 1
    if ($packagedImage) {
        Copy-Item -LiteralPath $packagedImage.FullName -Destination (Join-Path $targetDirectory $packagedImage.Name) -Force
        $config.backgroundImage = $packagedImage.Name
    }
}
$config.styleFile = '../../themes/dream/theme.css'
$config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath -Encoding UTF8
$mode = if ($BackgroundPath) { 'with background image' } else { 'color shell; add an image later' }
Write-Host "Installed local theme: $($config.name) ($mode)" -ForegroundColor Green
