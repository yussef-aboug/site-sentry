# SiteSentry -- weekly maintenance check (READ-ONLY).
# Runs the roster (what's due across all registered sites), writes a report to
# your Desktop, and pops a reminder. Makes NO changes to any site -- it only
# reports. Register it as a weekly task with register-weekly-check.ps1.
#
# The safe application of updates stays operator-run: you read this, then open
# Claude Code in maintenance-agent and run the maintenance-cycle with approvals.

$ErrorActionPreference = 'Stop'

# maintenance-agent/ is the parent of this script's folder (scripts/)
$agentDir = Split-Path -Parent $PSScriptRoot
$rosterWin = Join-Path $agentDir 'scripts\roster.sh'
if (-not (Test-Path $rosterWin)) { throw "roster.sh not found at $rosterWin" }

# Locate Git Bash (ships with Git for Windows)
$bash = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
  "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $bash) { throw "Git Bash not found. Install Git for Windows (it ships with bash)." }

# Convert C:\Users\..\maintenance-agent -> /c/Users/../maintenance-agent for bash
$drive = $agentDir.Substring(0,1).ToLower()
$agentUnix = '/' + $drive + ($agentDir.Substring(2) -replace '\\','/')

# Run the roster read-only; roster.sh finds sites/ relative to itself
$report = & $bash -lc "cd '$agentUnix' && ./scripts/roster.sh" 2>&1 | Out-String

# Save where you'll see it
$deskFile = Join-Path ([Environment]::GetFolderPath('Desktop')) 'SiteSentry-whats-due.txt'
("Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm')`r`n`r`n" + $report) |
  Out-File -FilePath $deskFile -Encoding utf8

# Count what needs attention and remind
$dueCount = ([regex]::Matches($report, 'DUE|OVERDUE')).Count
$msg = if ($dueCount -gt 0) {
  "$dueCount maintenance item(s) due across your sites.`n`nOpen Claude Code in maintenance-agent and run the maintenance cycle.`n`nDetails: SiteSentry-whats-due.txt on your Desktop."
} else {
  "All sites current -- nothing due this week.`n`nDetails: SiteSentry-whats-due.txt on your Desktop."
}
try {
  (New-Object -ComObject Wscript.Shell).Popup($msg, 60, "SiteSentry weekly check", 64) | Out-Null
} catch { }  # popup is best-effort; the Desktop report is the reliable output

Write-Output $report
