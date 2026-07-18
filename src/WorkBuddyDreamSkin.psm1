Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-WbdsWorkBuddyPath {
    param([string]$ExplicitPath)

    $candidates = @()
    if ($ExplicitPath) { $candidates += $ExplicitPath }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\WorkBuddy.exe')

    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($entry in (Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue | Where-Object {
        $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like 'WorkBuddy*'
    })) {
        if ($entry.PSObject.Properties['DisplayIcon'] -and $entry.DisplayIcon) {
            $candidates += ($entry.DisplayIcon -replace ',\d+$', '')
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'WorkBuddy.exe was not found. Install WorkBuddy or pass -WorkBuddyPath.'
}

function Get-WbdsTarget {
    param([int]$Port = 19333)
    try {
        $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 1
        return $targets | Where-Object {
            $_.type -eq 'page' -and ($_.title -like '*WorkBuddy*' -or $_.url -like '*app.asar/renderer/index.html*')
        } | Select-Object -First 1
    } catch {
        return $null
    }
}

function Wait-WbdsTarget {
    param([int]$Port = 19333, [int]$TimeoutSeconds = 25)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $target = Get-WbdsTarget -Port $Port
        if ($target) { return $target }
        Start-Sleep -Milliseconds 350
    } while ((Get-Date) -lt $deadline)
    throw "WorkBuddy started, but its CDP page was not available on 127.0.0.1:$Port."
}

function Invoke-WbdsCdpCommand {
    param(
        [Parameter(Mandatory = $true)][string]$WebSocketUrl,
        [Parameter(Mandatory = $true)][string]$Method,
        [hashtable]$Params = @{},
        [int]$TimeoutSeconds = 15
    )

    $socket = New-Object System.Net.WebSockets.ClientWebSocket
    $cts = New-Object System.Threading.CancellationTokenSource
    $cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSeconds))
    try {
        $socket.ConnectAsync([Uri]$WebSocketUrl, $cts.Token).GetAwaiter().GetResult()
        $requestId = Get-Random -Minimum 1000 -Maximum 999999
        $payload = @{ id = $requestId; method = $Method; params = $Params } | ConvertTo-Json -Depth 20 -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        $sendSegment = New-Object 'System.ArraySegment[byte]' -ArgumentList (, $bytes)
        $socket.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).GetAwaiter().GetResult()

        while ($true) {
            $stream = New-Object System.IO.MemoryStream
            do {
                $buffer = New-Object byte[] 65536
                $receiveSegment = New-Object 'System.ArraySegment[byte]' -ArgumentList (, $buffer)
                $received = $socket.ReceiveAsync($receiveSegment, $cts.Token).GetAwaiter().GetResult()
                if ($received.Count -gt 0) { $stream.Write($buffer, 0, $received.Count) }
            } while (-not $received.EndOfMessage)

            $message = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
            if ($message.PSObject.Properties['id'] -and $message.id -eq $requestId) {
                if ($message.PSObject.Properties['error'] -and $message.error) {
                    throw "CDP $Method failed: $($message.error.message)"
                }
                return $message.result
            }
        }
    } finally {
        if ($socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
            try { $socket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).GetAwaiter().GetResult() } catch {}
        }
        $socket.Dispose()
        $cts.Dispose()
    }
}

function ConvertTo-WbdsBackgroundValue {
    param([object]$Theme, [string]$ThemeDirectory)

    if ($Theme.backgroundImage) {
        $imagePath = [string]$Theme.backgroundImage
        if (-not [IO.Path]::IsPathRooted($imagePath)) { $imagePath = Join-Path $ThemeDirectory $imagePath }
        if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw "Theme background not found: $imagePath" }
        $file = Get-Item -LiteralPath $imagePath
        if ($file.Length -gt 12MB) { throw 'The background image must be 12 MB or smaller for the MVP injector.' }
        $mime = switch ($file.Extension.ToLowerInvariant()) {
            '.png'  { 'image/png' }
            '.webp' { 'image/webp' }
            '.gif'  { 'image/gif' }
            default { 'image/jpeg' }
        }
        $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file.FullName))
        return "url(`"data:$mime;base64,$base64`")"
    }
    return [string]$Theme.backgroundFallback
}

function Get-WbdsImagePalette {
    param([Parameter(Mandatory = $true)][string]$ImagePath)

    Add-Type -AssemblyName System.Drawing
    $image = Get-Item -LiteralPath $ImagePath -ErrorAction Stop
    $bitmap = New-Object Drawing.Bitmap $image.FullName
    try {
        $stepX = [Math]::Max(1, [int][Math]::Floor($bitmap.Width / 72))
        $stepY = [Math]::Max(1, [int][Math]::Floor($bitmap.Height / 72))
        $sumR = 0.0; $sumG = 0.0; $sumB = 0.0; $count = 0
        $buckets = @{}
        for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
            for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -lt 96) { continue }
                $sumR += $pixel.R; $sumG += $pixel.G; $sumB += $pixel.B; $count++
                $max = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
                $min = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
                $brightness = ($max + $min) / 510.0
                $saturation = if ($max -eq 0) { 0.0 } else { ($max - $min) / [double]$max }
                if ($brightness -gt 0.08 -and $brightness -lt 0.94 -and $saturation -gt 0.12) {
                    $qr = [Math]::Min(255, [int]([Math]::Floor($pixel.R / 32)) * 32 + 16)
                    $qg = [Math]::Min(255, [int]([Math]::Floor($pixel.G / 32)) * 32 + 16)
                    $qb = [Math]::Min(255, [int]([Math]::Floor($pixel.B / 32)) * 32 + 16)
                    $key = "$qr,$qg,$qb"
                    $weight = 1.0 + ($saturation * 2.5)
                    if ($buckets.ContainsKey($key)) { $buckets[$key] += $weight } else { $buckets[$key] = $weight }
                }
            }
        }
        if ($count -eq 0) { throw '图片中没有可分析的可见像素。' }
        $average = @([int]($sumR / $count), [int]($sumG / $count), [int]($sumB / $count))
        $dominant = $average
        if ($buckets.Count) {
            $top = $buckets.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $dominant = @($top.Key.Split(',') | ForEach-Object { [int]$_ })
        }
    } finally {
        $bitmap.Dispose()
    }

    $clamp = { param([double]$Value) [int][Math]::Max(0, [Math]::Min(255, [Math]::Round($Value))) }
    $mix = {
        param([int[]]$A, [int[]]$B, [double]$WeightB)
        @(
            (& $clamp ($A[0] * (1 - $WeightB) + $B[0] * $WeightB)),
            (& $clamp ($A[1] * (1 - $WeightB) + $B[1] * $WeightB)),
            (& $clamp ($A[2] * (1 - $WeightB) + $B[2] * $WeightB))
        )
    }
    $hex = { param([int[]]$Rgb) '#{0:X2}{1:X2}{2:X2}' -f $Rgb[0], $Rgb[1], $Rgb[2] }
    $luminance = { param([int[]]$Rgb) (0.2126 * $Rgb[0] + 0.7152 * $Rgb[1] + 0.0722 * $Rgb[2]) / 255.0 }
    $relativeLuminance = {
        param([int[]]$Rgb)
        $channels = @($Rgb | ForEach-Object {
            $value = $_ / 255.0
            if ($value -le 0.03928) { $value / 12.92 } else { [Math]::Pow((($value + 0.055) / 1.055), 2.4) }
        })
        0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
    }

    $mean = ($dominant[0] + $dominant[1] + $dominant[2]) / 3.0
    $accent = @(
        (& $clamp ($mean + ($dominant[0] - $mean) * 1.3)),
        (& $clamp ($mean + ($dominant[1] - $mean) * 1.3)),
        (& $clamp ($mean + ($dominant[2] - $mean) * 1.3))
    )
    $accentLum = & $luminance $accent
    if ($accentLum -lt 0.30) { $accent = & $mix $accent @(255, 255, 255) 0.32 }
    if ($accentLum -gt 0.78) { $accent = & $mix $accent @(0, 0, 0) 0.22 }

    $averageLum = & $luminance $average
    $scheme = if ($averageLum -ge 0.70) { 'light' } else { 'dark' }
    $white = @(255, 255, 255); $black = @(0, 0, 0)
    if ($scheme -eq 'light') {
        $canvas = & $mix $accent $white 0.91
        $surface = & $mix $accent $white 0.96
        $raised = & $mix $accent $white 0.87
        $sidebar = & $mix $accent $white 0.89
        $text = & $mix $accent $black 0.78
        $muted = & $mix $accent $black 0.52
        $border = & $mix $accent $white 0.58
        $heroShade = "rgba($($canvas[0]), $($canvas[1]), $($canvas[2]), 0.78)"
        $overlay = 0.10; $homeOverlay = 0.08; $taskOverlay = 0.45; $panelOpacity = 0.82
    } else {
        $canvas = & $mix $accent $black 0.74
        $surface = & $mix $accent $black 0.64
        $raised = & $mix $accent $black 0.50
        $sidebar = & $mix $accent $black 0.70
        $text = & $mix $accent $white 0.91
        $muted = & $mix $accent $white 0.62
        $border = & $mix $accent $black 0.25
        $heroShade = "rgba($($canvas[0]), $($canvas[1]), $($canvas[2]), 0.74)"
        $overlay = 0.20; $homeOverlay = 0.18; $taskOverlay = 0.56; $panelOpacity = 0.76
    }
    $accentRelative = & $relativeLuminance $accent
    $darkControlText = @(16, 19, 33)
    $darkContrast = ($accentRelative + 0.05) / ((& $relativeLuminance $darkControlText) + 0.05)
    $lightContrast = (1.0 + 0.05) / ($accentRelative + 0.05)
    $accentContrast = if ($darkContrast -gt $lightContrast) { '#101321' } else { '#FFFFFF' }
    $accentHex = & $hex $accent
    $canvasHex = & $hex $canvas
    $raisedHex = & $hex $raised
    $palette = @{
        colorScheme = $scheme
        canvasColor = $canvasHex
        surfaceColor = (& $hex $surface)
        surfaceRaisedColor = $raisedHex
        sidebarColor = (& $hex $sidebar)
        textColor = (& $hex $text)
        mutedTextColor = (& $hex $muted)
        accentColor = $accentHex
        accentContrastColor = $accentContrast
        borderColor = (& $hex $border)
        heroShadeColor = $heroShade
        backgroundFallback = "radial-gradient(circle at 78% 18%, $accentHex 0, transparent 32%), linear-gradient(145deg, $canvasHex, $raisedHex)"
        overlayOpacity = $overlay
        panelOpacity = $panelOpacity
        homeOverlayOpacity = $homeOverlay
        taskOverlayOpacity = $taskOverlay
    }
    [pscustomobject]@{
        Scheme = $scheme
        AccentColor = $accentHex
        AverageLuminance = [Math]::Round($averageLum, 3)
        Palette = $palette
    }
}

function Get-WbdsThemeCss {
    param([Parameter(Mandatory = $true)][string]$ThemePath)

    $themeFile = (Resolve-Path -LiteralPath $ThemePath).Path
    $themeDirectory = Split-Path -Parent $themeFile
    $theme = Get-Content -LiteralPath $themeFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $styleFile = if ($theme.PSObject.Properties['styleFile'] -and $theme.styleFile) { [string]$theme.styleFile } else { 'theme.css' }
    $cssPath = Join-Path $themeDirectory $styleFile
    $css = Get-Content -LiteralPath $cssPath -Raw -Encoding UTF8
    $background = ConvertTo-WbdsBackgroundValue -Theme $theme -ThemeDirectory $themeDirectory
    $homeOverlay = if ($theme.PSObject.Properties['homeOverlayOpacity']) { [double]$theme.homeOverlayOpacity } else { [double]$theme.overlayOpacity }
    $taskOverlay = if ($theme.PSObject.Properties['taskOverlayOpacity']) { [double]$theme.taskOverlayOpacity } else { [Math]::Min(0.85, ([double]$theme.overlayOpacity + 0.2)) }
    $themeValue = {
        param([string]$Name, [string]$Fallback)
        if ($theme.PSObject.Properties[$Name] -and $theme.$Name) { return [string]$theme.$Name }
        return $Fallback
    }
    $replacements = @{
        '__WBDS_BACKGROUND__' = $background
        '__WBDS_AVATAR__' = $background
        '__WBDS_AVATAR_POSITION__' = (& $themeValue 'avatarPosition' 'center center')
        '__WBDS_AVATAR_SIZE__' = (& $themeValue 'avatarSize' 'cover')
        '__WBDS_POSITION__' = [string]$theme.backgroundPosition
        '__WBDS_SIZE__' = [string]$theme.backgroundSize
        '__WBDS_OVERLAY__' = ([double]$theme.overlayOpacity).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_PANEL__' = ([double]$theme.panelOpacity).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_BLUR__' = ([double]$theme.panelBlurPx).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_SATURATION__' = ([double]$theme.panelSaturation).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_RADIUS__' = ([double]$theme.radiusPx).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_HOME_OVERLAY__' = $homeOverlay.ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_TASK_OVERLAY__' = $taskOverlay.ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_COLOR_SCHEME__' = (& $themeValue 'colorScheme' 'dark')
        '__WBDS_CANVAS__' = (& $themeValue 'canvasColor' '#111522')
        '__WBDS_SURFACE__' = (& $themeValue 'surfaceColor' '#181d2c')
        '__WBDS_SURFACE_RAISED__' = (& $themeValue 'surfaceRaisedColor' '#22283a')
        '__WBDS_SIDEBAR__' = (& $themeValue 'sidebarColor' '#151a29')
        '__WBDS_TEXT__' = (& $themeValue 'textColor' '#f4f5fb')
        '__WBDS_TEXT_MUTED__' = (& $themeValue 'mutedTextColor' '#aeb5c9')
        '__WBDS_ACCENT__' = (& $themeValue 'accentColor' '#8b7cff')
        '__WBDS_ACCENT_CONTRAST__' = (& $themeValue 'accentContrastColor' '#ffffff')
        '__WBDS_BORDER__' = (& $themeValue 'borderColor' '#3d4358')
        '__WBDS_HERO_SHADE__' = (& $themeValue 'heroShadeColor' 'rgba(17, 21, 34, 0.92)')
    }
    foreach ($key in $replacements.Keys) { $css = $css.Replace($key, $replacements[$key]) }
    return @{ Id = [string]$theme.id; Name = [string]$theme.name; Scheme = (& $themeValue 'colorScheme' 'dark'); Css = $css }
}

function Get-WbdsThemes {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $roots = @(
        (Join-Path $ProjectRoot 'themes'),
        (Join-Path $ProjectRoot 'themes-local')
    )
    $themes = foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $root -Recurse -Filter theme.json -File -ErrorAction SilentlyContinue)) {
            try {
                $config = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                [pscustomobject]@{
                    Id = [string]$config.id
                    Name = [string]$config.name
                    Description = [string]$config.description
                    Kind = [string]$config.kind
                    Path = $file.FullName
                    HasBackground = (-not $config.backgroundImage) -or (Test-Path -LiteralPath (Join-Path $file.DirectoryName ([string]$config.backgroundImage)))
                }
            } catch {
                Write-Warning "Skipped invalid theme: $($file.FullName)"
            }
        }
    }
    return @($themes | Sort-Object Kind, Name)
}

function Get-WbdsStatePath {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $stateDirectory = Join-Path $ProjectRoot 'work'
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    return (Join-Path $stateDirectory 'state.json')
}

function Save-WbdsThemeState {
    param([string]$ProjectRoot, [string]$ThemeId, [string]$ThemePath)
    @{ themeId = $ThemeId; themePath = $ThemePath; savedAt = (Get-Date).ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Get-WbdsStatePath -ProjectRoot $ProjectRoot) -Encoding UTF8
}

function Get-WbdsSavedThemePath {
    param([string]$ProjectRoot)
    $path = Get-WbdsStatePath -ProjectRoot $ProjectRoot
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $state = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.themePath -and (Test-Path -LiteralPath $state.themePath -PathType Leaf)) { return [string]$state.themePath }
    } catch {}
    return $null
}

function New-WbdsCustomTheme {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$BaseThemePath,
        [Parameter(Mandatory = $true)][string]$BackgroundPath,
        [string]$CustomId,
        [string]$CustomName,
        [string]$Description = '本地自定义背景；不会上传到仓库。',
        [string]$BackgroundPosition,
        [hashtable]$Palette
    )

    $image = Get-Item -LiteralPath $BackgroundPath -ErrorAction Stop
    if ($image.Length -gt 12MB) { throw 'The background image must be 12 MB or smaller.' }
    $extension = $image.Extension.ToLowerInvariant()
    if ($extension -notin @('.jpg', '.jpeg', '.png', '.webp', '.gif')) { throw 'Supported image types: JPG, PNG, WebP, and GIF.' }

    $config = Get-Content -LiteralPath $BaseThemePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $baseId = ([string]$config.id) -replace '^custom-', ''
    if (-not $baseId) { throw 'The base theme must have an id.' }
    $customId = if ($CustomId) { $CustomId } else { "custom-$baseId" }
    if ($customId -notmatch '^[a-z0-9][a-z0-9-]*$') { throw 'The custom theme id may only contain lowercase letters, numbers, and hyphens.' }
    $targetDirectory = Join-Path $ProjectRoot "themes-local\$customId"
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    Get-ChildItem -LiteralPath $targetDirectory -Filter 'background.*' -File -ErrorAction SilentlyContinue | Remove-Item -Force
    $targetImage = Join-Path $targetDirectory ("background{0}" -f $extension)
    Copy-Item -LiteralPath $image.FullName -Destination $targetImage -Force

    $baseName = ([string]$config.name) -replace '^我的图片 · ', ''
    $config.id = $customId
    $config.name = if ($CustomName) { $CustomName } else { "我的图片 · $baseName" }
    $config.description = $Description
    $config.kind = 'custom'
    $config.backgroundImage = [IO.Path]::GetFileName($targetImage)
    if ($BackgroundPosition) { $config.backgroundPosition = $BackgroundPosition }
    if ($Palette) {
        foreach ($entry in $Palette.GetEnumerator()) {
            if ($config.PSObject.Properties[$entry.Key]) {
                $config.($entry.Key) = $entry.Value
            } else {
                $config | Add-Member -NotePropertyName $entry.Key -NotePropertyValue $entry.Value
            }
        }
    }
    if ($config.PSObject.Properties['styleFile']) {
        $config.styleFile = '../../themes/dream/theme.css'
    } else {
        $config | Add-Member -NotePropertyName styleFile -NotePropertyValue '../../themes/dream/theme.css'
    }
    $targetConfig = Join-Path $targetDirectory 'theme.json'
    $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $targetConfig -Encoding UTF8
    return [pscustomobject]@{ Id = $customId; Path = $targetConfig; ImagePath = $targetImage }
}

function Set-WbdsTheme {
    param(
        [Parameter(Mandatory = $true)][string]$WebSocketUrl,
        [Parameter(Mandatory = $true)][string]$ThemePath
    )
    $theme = Get-WbdsThemeCss -ThemePath $ThemePath
    $cssLiteral = $theme.Css | ConvertTo-Json -Compress
    $nameLiteral = $theme.Name | ConvertTo-Json -Compress
    $schemeLiteral = $theme.Scheme | ConvertTo-Json -Compress
    $expression = @"
(() => {
  const css = $cssLiteral;
  let style = document.getElementById('wbds-theme-style');
  if (!style) {
    style = document.createElement('style');
    style.id = 'wbds-theme-style';
    document.head.appendChild(style);
  }
  style.textContent = css;
  let background = document.getElementById('wbds-background');
  if (!background) {
    background = document.createElement('div');
    background.id = 'wbds-background';
    background.setAttribute('aria-hidden', 'true');
    document.body.prepend(background);
  }
  document.documentElement.classList.add('wbds-active');
  const updatePageMode = () => {
    const isHome = !!document.querySelector('.main-content--welcome');
    document.documentElement.classList.toggle('wbds-home', isHome);
    document.documentElement.classList.toggle('wbds-task', !isHome);
  };
  updatePageMode();
  if (window.__wbdsModeObserver) window.__wbdsModeObserver.disconnect();
  window.__wbdsModeObserver = new MutationObserver(updatePageMode);
  window.__wbdsModeObserver.observe(document.body, {subtree: true, childList: true});
  document.documentElement.dataset.wbdsTheme = $nameLiteral;
  document.documentElement.dataset.wbdsScheme = $schemeLiteral;
  return { ok: true, theme: $nameLiteral, scheme: $schemeLiteral, title: document.title };
})()
"@
    $result = Invoke-WbdsCdpCommand -WebSocketUrl $WebSocketUrl -Method 'Runtime.evaluate' -Params @{
        expression = $expression
        returnByValue = $true
        awaitPromise = $true
    }
    if ($result.PSObject.Properties['exceptionDetails'] -and $result.exceptionDetails) {
        throw "Theme injection failed: $($result.exceptionDetails.text)"
    }
    return $result
}

function Remove-WbdsTheme {
    param([Parameter(Mandatory = $true)][string]$WebSocketUrl)
    $expression = @"
(() => {
  document.getElementById('wbds-theme-style')?.remove();
  document.getElementById('wbds-background')?.remove();
  document.documentElement.classList.remove('wbds-active');
  document.documentElement.classList.remove('wbds-home', 'wbds-task');
  if (window.__wbdsModeObserver) {
    window.__wbdsModeObserver.disconnect();
    delete window.__wbdsModeObserver;
  }
  delete document.documentElement.dataset.wbdsTheme;
  delete document.documentElement.dataset.wbdsScheme;
  return { ok: true, title: document.title };
})()
"@
    $result = Invoke-WbdsCdpCommand -WebSocketUrl $WebSocketUrl -Method 'Runtime.evaluate' -Params @{
        expression = $expression
        returnByValue = $true
    }
    if ($result.PSObject.Properties['exceptionDetails'] -and $result.exceptionDetails) {
        throw "Theme restore failed: $($result.exceptionDetails.text)"
    }
    return $result
}

Export-ModuleMember -Function Get-WbdsWorkBuddyPath, Get-WbdsTarget, Wait-WbdsTarget, Invoke-WbdsCdpCommand, Get-WbdsImagePalette, Get-WbdsThemeCss, Set-WbdsTheme, Remove-WbdsTheme, Get-WbdsThemes, Get-WbdsSavedThemePath, Save-WbdsThemeState, New-WbdsCustomTheme
