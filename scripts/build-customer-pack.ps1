[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ClientName,
    [string]$ThemeName,
    [Parameter(Mandatory = $true)][string]$BackgroundPath,
    [string]$BaseThemePath,
    [switch]$AutoPalette,
    [string]$OutputDirectory,
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force
if (-not $BaseThemePath) { $BaseThemePath = Join-Path $projectRoot 'themes\dream\theme.json' }
if (-not $OutputDirectory) { $OutputDirectory = [Environment]::GetFolderPath('Desktop') }
if (-not $Version) { $Version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') -Raw -Encoding UTF8).Trim() }

$client = $ClientName.Trim()
if (-not $client) { throw '请填写客户名称。' }
if (-not $ThemeName) { $ThemeName = "$client · 专属主题" }
$image = Get-Item -LiteralPath $BackgroundPath -ErrorAction Stop
if ($image.Length -gt 12MB) { throw '客户图片不能超过 12 MB。' }
$extension = $image.Extension.ToLowerInvariant()
if ($extension -notin @('.jpg', '.jpeg', '.png', '.webp', '.gif')) { throw '仅支持 JPG、PNG、WebP 和 GIF 图片。' }
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) { throw '输出文件夹不存在。' }

$resolvedProject = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
$resolvedBase = (Resolve-Path -LiteralPath $BaseThemePath).Path
if (-not $resolvedBase.StartsWith($resolvedProject, [StringComparison]::OrdinalIgnoreCase)) {
    throw '基础主题必须来自当前 WorkBuddy Dream Skin 项目。'
}

$safeName = ($client -replace '[\\/:*?"<>|]', '_').Trim('. ')
if (-not $safeName) { $safeName = 'Customer' }
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $hashBytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($client))
} finally {
    $sha.Dispose()
}
$suffix = -join ($hashBytes[0..3] | ForEach-Object { $_.ToString('x2') })
$themeId = "customer-$suffix"

$workRoot = Join-Path $projectRoot 'work\customer-packs'
New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
$staging = Join-Path $workRoot ("{0}-{1}" -f $themeId, [Guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $staging ("WorkBuddy-定制皮肤-{0}" -f $safeName)
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

try {
    $directories = @('docs', 'scripts', 'src', 'theme-examples', 'themes', 'tests')
    foreach ($directory in $directories) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $directory) -Destination (Join-Path $packageRoot $directory) -Recurse -Force
    }
    foreach ($sellerScript in @('build-customer-pack.ps1', 'customer-pack-studio.ps1')) {
        $sellerScriptPath = Join-Path $packageRoot "scripts\$sellerScript"
        if (Test-Path -LiteralPath $sellerScriptPath -PathType Leaf) { Remove-Item -LiteralPath $sellerScriptPath -Force }
    }
    $files = @(
        'CHANGELOG.md', 'LICENSE', 'README.md', 'VERSION',
        'Start Dream Skin.cmd', 'Switch Theme.cmd', 'Restore WorkBuddy.cmd',
        'Install Anime Theme Shells.cmd', 'Theme Studio.cmd',
        'Install WorkBuddy Dream Skin.cmd', 'Uninstall WorkBuddy Dream Skin.cmd'
    )
    foreach ($file in $files) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $packageRoot $file) -Force
    }

    $customerThemeDirectory = Join-Path $packageRoot "themes\$themeId"
    New-Item -ItemType Directory -Path $customerThemeDirectory -Force | Out-Null
    $targetImageName = "background$extension"
    Copy-Item -LiteralPath $image.FullName -Destination (Join-Path $customerThemeDirectory $targetImageName) -Force

    $config = Get-Content -LiteralPath $resolvedBase -Raw -Encoding UTF8 | ConvertFrom-Json
    $config.id = $themeId
    $config.name = $ThemeName.Trim()
    $config.description = "$client 的本地专属 WorkBuddy 主题。"
    $config.kind = 'customer'
    $config.backgroundImage = $targetImageName
    $paletteSummary = '手动基础配色'
    if ($AutoPalette) {
        $analysis = Get-WbdsImagePalette -ImagePath $image.FullName
        foreach ($entry in $analysis.Palette.GetEnumerator()) {
            if ($config.PSObject.Properties[$entry.Key]) {
                $config.($entry.Key) = $entry.Value
            } else {
                $config | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value
            }
        }
        $paletteSummary = "自动取色：$($analysis.Scheme) / $($analysis.AccentColor)"
        $config.description = "$client 的本地专属 WorkBuddy 主题；$paletteSummary。"
    }
    if ($config.PSObject.Properties['styleFile']) {
        $config.styleFile = '../dream/theme.css'
    } else {
        $config | Add-Member -NotePropertyName styleFile -NotePropertyValue '../dream/theme.css'
    }
    if (-not $config.PSObject.Properties['avatarPosition']) { $config | Add-Member -NotePropertyName avatarPosition -NotePropertyValue 'center center' }
    if (-not $config.PSObject.Properties['avatarSize']) { $config | Add-Member -NotePropertyName avatarSize -NotePropertyValue 'cover' }
    $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $customerThemeDirectory 'theme.json') -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $packageRoot 'customer-default-theme.txt') -Value $themeId -Encoding ASCII
    $instructions = @"
$client 的 WorkBuddy 定制皮肤

安装步骤：
1. 先安装腾讯 WorkBuddy。
2. 双击“Install WorkBuddy Dream Skin.cmd”。
3. 安装完成后会打开主题中心，并自动选中“$($config.name)”。
4. 如果 WorkBuddy 正在运行，请先从系统托盘完全退出。
5. 点击“应用主题”。以后从桌面的“切换 WorkBuddy 主题”进入。

配色方式：$paletteSummary

隐私说明：本安装包中的客户图片仅在本机使用；工具不会上传图片、账号、任务或 API Key。
技术支持：请联系向你提供本安装包的定制服务方。
"@
    Set-Content -LiteralPath (Join-Path $packageRoot '客户安装说明.txt') -Value $instructions -Encoding UTF8

    $archive = Join-Path $OutputDirectory ("WorkBuddy-定制皮肤-{0}-Windows-v{1}.zip" -f $safeName, $Version)
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
    Compress-Archive -LiteralPath $packageRoot -DestinationPath $archive -CompressionLevel Optimal
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $hashPath = "$archive.sha256"
    Set-Content -LiteralPath $hashPath -Value "$hash  $([IO.Path]::GetFileName($archive))" -Encoding ASCII
    [pscustomobject]@{
        Archive = $archive
        HashPath = $hashPath
        ThemeId = $themeId
        ThemeName = [string]$config.name
        PaletteMode = $paletteSummary
        SHA256 = $hash
    }
} finally {
    $resolvedWorkRoot = [IO.Path]::GetFullPath($workRoot).TrimEnd('\')
    $resolvedStaging = [IO.Path]::GetFullPath($staging)
    if ($resolvedStaging.StartsWith($resolvedWorkRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedStaging)) {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
