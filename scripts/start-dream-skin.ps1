[CmdletBinding()]
param(
    [string]$WorkBuddyPath,
    [string]$ThemePath,
    [int]$Port = 19333,
    [string]$UserDataDir
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

try {
    if (-not $ThemePath) { $ThemePath = Join-Path $projectRoot 'themes\dream\theme.json' }
    $exe = Get-WbdsWorkBuddyPath -ExplicitPath $WorkBuddyPath
    $target = Get-WbdsTarget -Port $Port

    if (-not $target) {
        $running = Get-Process -Name WorkBuddy -ErrorAction SilentlyContinue
        if ($running) {
            throw "WorkBuddy is already running without the Dream Skin debug port. Close WorkBuddy completely (including its tray process), then run this script again."
        }
        $arguments = @("--remote-debugging-address=127.0.0.1", "--remote-debugging-port=$Port")
        if ($UserDataDir) {
            New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null
            $arguments += "--user-data-dir=$UserDataDir"
        }
        Start-Process -FilePath $exe -ArgumentList $arguments | Out-Null
        $target = Wait-WbdsTarget -Port $Port
    }

    $result = Set-WbdsTheme -WebSocketUrl $target.webSocketDebuggerUrl -ThemePath $ThemePath
    $value = $result.result.value
    Write-Host "Dream Skin applied: $($value.theme)" -ForegroundColor Green
    Write-Host "CDP is bound to 127.0.0.1:$Port. Run 'Restore WorkBuddy.cmd' to remove the live theme."
} catch {
    Write-Error $_
    exit 1
}

