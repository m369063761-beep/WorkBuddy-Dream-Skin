[CmdletBinding()]
param(
    [int]$Port = 19333,
    [switch]$SkipWorkBuddyCheck
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

$checks = @()
if ($SkipWorkBuddyCheck) {
    $checks += [pscustomobject]@{ Check = 'WorkBuddy executable'; Result = 'INFO'; Detail = 'Skipped' }
} else {
    try {
        $exe = Get-WbdsWorkBuddyPath
        $checks += [pscustomobject]@{ Check = 'WorkBuddy executable'; Result = 'PASS'; Detail = $exe }
    } catch {
        $checks += [pscustomobject]@{ Check = 'WorkBuddy executable'; Result = 'FAIL'; Detail = $_.Exception.Message }
    }
}

$target = Get-WbdsTarget -Port $Port
if ($target) {
    $checks += [pscustomobject]@{ Check = 'Dream Skin CDP session'; Result = 'PASS'; Detail = $target.title }
} else {
    $checks += [pscustomobject]@{ Check = 'Dream Skin CDP session'; Result = 'INFO'; Detail = 'Not running' }
}

$themePath = Join-Path $projectRoot 'themes\dream\theme.json'
try {
    $null = Get-Content -LiteralPath $themePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $checks += [pscustomobject]@{ Check = 'Theme configuration'; Result = 'PASS'; Detail = $themePath }
} catch {
    $checks += [pscustomobject]@{ Check = 'Theme configuration'; Result = 'FAIL'; Detail = $_.Exception.Message }
}

$checks | Format-Table -AutoSize
if ($checks.Result -contains 'FAIL') { exit 1 }
