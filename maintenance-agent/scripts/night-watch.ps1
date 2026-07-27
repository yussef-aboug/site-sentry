# SiteSentry Night Watch -- Windows wrapper. Runs the read-only outage poller
# (night-watch.sh) via Git Bash. Registered to run every ~5 minutes by
# register-night-watch.ps1. Makes NO changes to any site; alerts go out via ntfy
# (configure scripts/night-watch.local.conf first).
$ErrorActionPreference = 'Stop'

$agentDir = Split-Path -Parent $PSScriptRoot
$bash = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
  "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $bash) { throw "Git Bash not found. Install Git for Windows." }

$drive = $agentDir.Substring(0,1).ToLower()
$agentUnix = '/' + $drive + ($agentDir.Substring(2) -replace '\\','/')

# Pass through --force for manual testing:  night-watch.ps1 -Force
$forceArg = if ($args -contains '-Force') { ' --force' } else { '' }

& $bash -lc "cd '$agentUnix' && ./scripts/night-watch.sh$forceArg" 2>&1 | Write-Output
