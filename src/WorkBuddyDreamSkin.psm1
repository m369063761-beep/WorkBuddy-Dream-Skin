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

function Get-WbdsThemeCss {
    param([Parameter(Mandatory = $true)][string]$ThemePath)

    $themeFile = (Resolve-Path -LiteralPath $ThemePath).Path
    $themeDirectory = Split-Path -Parent $themeFile
    $theme = Get-Content -LiteralPath $themeFile -Raw | ConvertFrom-Json
    $cssPath = Join-Path $themeDirectory 'theme.css'
    $css = Get-Content -LiteralPath $cssPath -Raw
    $background = ConvertTo-WbdsBackgroundValue -Theme $theme -ThemeDirectory $themeDirectory
    $replacements = @{
        '__WBDS_BACKGROUND__' = $background
        '__WBDS_POSITION__' = [string]$theme.backgroundPosition
        '__WBDS_SIZE__' = [string]$theme.backgroundSize
        '__WBDS_OVERLAY__' = ([double]$theme.overlayOpacity).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_PANEL__' = ([double]$theme.panelOpacity).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_BLUR__' = ([double]$theme.panelBlurPx).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_SATURATION__' = ([double]$theme.panelSaturation).ToString([Globalization.CultureInfo]::InvariantCulture)
        '__WBDS_RADIUS__' = ([double]$theme.radiusPx).ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    foreach ($key in $replacements.Keys) { $css = $css.Replace($key, $replacements[$key]) }
    return @{ Name = [string]$theme.name; Css = $css }
}

function Set-WbdsTheme {
    param(
        [Parameter(Mandatory = $true)][string]$WebSocketUrl,
        [Parameter(Mandatory = $true)][string]$ThemePath
    )
    $theme = Get-WbdsThemeCss -ThemePath $ThemePath
    $cssLiteral = $theme.Css | ConvertTo-Json -Compress
    $nameLiteral = $theme.Name | ConvertTo-Json -Compress
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
  document.documentElement.dataset.wbdsTheme = $nameLiteral;
  return { ok: true, theme: $nameLiteral, title: document.title };
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
  delete document.documentElement.dataset.wbdsTheme;
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

Export-ModuleMember -Function Get-WbdsWorkBuddyPath, Get-WbdsTarget, Wait-WbdsTarget, Invoke-WbdsCdpCommand, Set-WbdsTheme, Remove-WbdsTheme
