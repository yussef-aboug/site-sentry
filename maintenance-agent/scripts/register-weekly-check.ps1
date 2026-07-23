# SiteSentry -- one-time: register the weekly maintenance check as a Windows
# scheduled task. Runs weekly-check.ps1 every Monday at 9:00 AM (read-only).
# Re-run this to change the schedule; use -Unregister to remove it.
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\register-weekly-check.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\register-weekly-check.ps1 -Unregister

param(
  [string]$Day = 'Monday',
  [string]$At  = '9:00AM',
  [switch]$Unregister
)

$ErrorActionPreference = 'Stop'
$taskName = 'SiteSentry Weekly Check'

if ($Unregister) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Output "Removed scheduled task '$taskName'."
  return
}

$check = Join-Path $PSScriptRoot 'weekly-check.ps1'
if (-not (Test-Path $check)) { throw "weekly-check.ps1 not found next to this script." }

$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$check`""
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Day -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -Settings $settings -Description 'Read-only: reports what maintenance is due across SiteSentry sites. Makes no changes.' -Force | Out-Null

Write-Output "Registered '$taskName' -- runs $Day at $At. It only reports what's due; it makes no changes."
Write-Output "Test it now with:  powershell -ExecutionPolicy Bypass -File `"$check`""
