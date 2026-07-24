# SiteSentry -- one-time: register the Night Watch poller as a Windows scheduled
# task that runs every 5 minutes, 24/7. The poller only ACTS during the
# after-hours window (see night-watch.local.conf); outside it, it exits immediately.
# It is read-only -- it detects outages and alerts you; it makes no changes.
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\register-night-watch.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\register-night-watch.ps1 -Every 5
#   powershell -ExecutionPolicy Bypass -File .\scripts\register-night-watch.ps1 -Unregister

param(
  [int]$Every = 5,          # minutes between checks
  [switch]$Unregister
)

$ErrorActionPreference = 'Stop'
$taskName = 'SiteSentry Night Watch'

if ($Unregister) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Output "Removed scheduled task '$taskName'."
  return
}

$wrapper = Join-Path $PSScriptRoot 'night-watch.ps1'
if (-not (Test-Path $wrapper)) { throw "night-watch.ps1 not found next to this script." }
$conf = Join-Path $PSScriptRoot 'night-watch.local.conf'
if (-not (Test-Path $conf)) {
  Write-Warning "night-watch.local.conf not found. Copy night-watch.conf.example to it and set your ntfy topic, or alerts won't send."
}

$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$wrapper`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Minutes $Every) `
  -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -Settings $settings -Description 'Read-only after-hours outage watcher. Detects down sites and alerts; makes no changes.' -Force | Out-Null

Write-Output "Registered '$taskName' -- runs every $Every min (acts only during your after-hours window)."
Write-Output "Test the poller now (ignores the time window):"
Write-Output "  powershell -ExecutionPolicy Bypass -File `"$wrapper`" -Force"
Write-Output "NOTE: your PC must stay awake overnight for this to fire. Consider disabling sleep 8 PM-8 AM."
