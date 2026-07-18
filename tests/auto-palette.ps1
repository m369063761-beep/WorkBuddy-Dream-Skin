$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $projectRoot 'work\auto-palette-test'
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force
Add-Type -AssemblyName System.Drawing

function New-SolidTestImage {
    param([string]$Path, [Drawing.Color]$Color)
    $bitmap = New-Object Drawing.Bitmap 24, 24
    try {
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        try { $graphics.Clear($Color) } finally { $graphics.Dispose() }
        $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $bitmap.Dispose() }
}

function Get-RelativeLuminance {
    param([string]$Hex)
    $rgb = @((1, 3, 5) | ForEach-Object { [Convert]::ToInt32($Hex.Substring($_, 2), 16) })
    $channels = @($rgb | ForEach-Object {
        $value = $_ / 255.0
        if ($value -le 0.03928) { $value / 12.92 } else { [Math]::Pow((($value + 0.055) / 1.055), 2.4) }
    })
    0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
}

function Get-ContrastRatio {
    param([string]$First, [string]$Second)
    $a = Get-RelativeLuminance $First
    $b = Get-RelativeLuminance $Second
    ([Math]::Max($a, $b) + 0.05) / ([Math]::Min($a, $b) + 0.05)
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $darkPath = Join-Path $testRoot 'dark-blue.png'
    $lightPath = Join-Path $testRoot 'light-pink.png'
    New-SolidTestImage -Path $darkPath -Color ([Drawing.Color]::FromArgb(28, 78, 165))
    New-SolidTestImage -Path $lightPath -Color ([Drawing.Color]::FromArgb(246, 220, 228))
    $dark = Get-WbdsImagePalette -ImagePath $darkPath
    $light = Get-WbdsImagePalette -ImagePath $lightPath
    if ($dark.Scheme -ne 'dark') { throw 'Dark image should produce a dark palette.' }
    if ($light.Scheme -ne 'light') { throw 'Light image should produce a light palette.' }
    foreach ($result in @($dark, $light)) {
        foreach ($key in @('canvasColor', 'surfaceColor', 'surfaceRaisedColor', 'sidebarColor', 'textColor', 'mutedTextColor', 'accentColor', 'borderColor')) {
            if ($result.Palette[$key] -notmatch '^#[0-9A-F]{6}$') { throw "Invalid generated color token: $key" }
        }
        if ((Get-ContrastRatio $result.Palette.textColor $result.Palette.canvasColor) -lt 4.5) { throw 'Generated canvas text contrast is below 4.5:1.' }
        if ((Get-ContrastRatio $result.Palette.accentContrastColor $result.Palette.accentColor) -lt 4.5) { throw 'Generated accent text contrast is below 4.5:1.' }
    }
    Write-Host "PASS: automatic image palettes produced dark $($dark.AccentColor) and light $($light.AccentColor) themes." -ForegroundColor Green
} finally {
    $resolvedWork = [IO.Path]::GetFullPath((Join-Path $projectRoot 'work')).TrimEnd('\')
    $resolvedTest = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTest.StartsWith($resolvedWork, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTest)) {
        Remove-Item -LiteralPath $resolvedTest -Recurse -Force
    }
}
