[CmdletBinding()]
param([int]$Port = 19335)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edgeCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
)
$edge = $edgeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge is required for the smoke test.' }

$profile = Join-Path $projectRoot 'work\edge-smoke-profile'
New-Item -ItemType Directory -Path $profile -Force | Out-Null
$arguments = @('--headless=new', "--remote-debugging-port=$Port", "--user-data-dir=$profile", 'about:blank')
$process = Start-Process -FilePath $edge -ArgumentList $arguments -WindowStyle Hidden -PassThru

try {
    $targets = $null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 1
            break
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    $target = $targets | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
    if (-not $target) { throw 'No Chromium CDP page target was found.' }

    Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force
    $themePath = Join-Path $projectRoot 'themes\dream\theme.json'
    $null = Set-WbdsTheme -WebSocketUrl $target.webSocketDebuggerUrl -ThemePath $themePath

    $probe = Invoke-WbdsCdpCommand -WebSocketUrl $target.webSocketDebuggerUrl -Method 'Runtime.evaluate' -Params @{
        expression = "({active:document.documentElement.classList.contains('wbds-active'),style:!!document.getElementById('wbds-theme-style'),background:!!document.getElementById('wbds-background')})"
        returnByValue = $true
    }
    $injected = $probe.result.value
    if (-not ($injected.active -and $injected.style -and $injected.background)) {
        throw "Injection assertions failed: $($injected | ConvertTo-Json -Compress)"
    }

    $null = Remove-WbdsTheme -WebSocketUrl $target.webSocketDebuggerUrl
    $probe = Invoke-WbdsCdpCommand -WebSocketUrl $target.webSocketDebuggerUrl -Method 'Runtime.evaluate' -Params @{
        expression = "({active:document.documentElement.classList.contains('wbds-active'),style:!!document.getElementById('wbds-theme-style'),background:!!document.getElementById('wbds-background')})"
        returnByValue = $true
    }
    $restored = $probe.result.value
    if ($restored.active -or $restored.style -or $restored.background) {
        throw "Restore assertions failed: $($restored | ConvertTo-Json -Compress)"
    }

    Write-Host 'PASS: CDP inject and restore smoke test' -ForegroundColor Green
} finally {
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq 'msedge.exe' -and $_.CommandLine -like "*--remote-debugging-port=$Port*"
    } | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
