[CmdletBinding()]
param([int]$Port = 19333)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

try {
    $target = Get-WbdsTarget -Port $Port
    if (-not $target) {
        Write-Host 'No live Dream Skin session was found. WorkBuddy is already using its normal appearance.' -ForegroundColor Yellow
        exit 0
    }
    $null = Remove-WbdsTheme -WebSocketUrl $target.webSocketDebuggerUrl
    Write-Host 'Dream Skin removed. WorkBuddy is back to its original live appearance.' -ForegroundColor Green
} catch {
    Write-Error $_
    exit 1
}

