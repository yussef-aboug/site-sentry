# SiteSentry — run a prospect health check from PowerShell.
# PowerShell has no `bash`, so this finds Git Bash and runs the scan for you.
#
#   powershell -ExecutionPolicy Bypass -File .\scripts\prospect-check.ps1 -Site example.com
#
#   # ...and build the client-ready report in one go:
#   .\scripts\prospect-check.ps1 -Site example.com -Report `
#       -Business "Sunrise Bakery" -Name "Sarah" -Plan "Peace of Mind — $229/mo" `
#       -Why "..." -Concern "it went down last month"
#
# Read-only. Runs only ordinary public requests; makes no changes to the site.
# Only run this against a site whose owner asked you to look.

param(
  [Parameter(Mandatory = $true)][string]$Site,
  [switch]$Report,
  [string]$Business = '',
  [string]$Name     = '',
  [string]$Plan     = '',
  [string]$Why      = '',
  [string]$Concern  = '',
  [string]$Out      = ''
)

$ErrorActionPreference = 'Stop'
$agentDir = Split-Path -Parent $PSScriptRoot

$bash = @(
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
  "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $bash) { throw "Git Bash not found. Install Git for Windows (https://git-scm.com/download/win)." }

# C:\path -> /c/path, the form Git Bash understands
$drive    = $agentDir.Substring(0,1).ToLower()
$agentUnix = '/' + $drive + ($agentDir.Substring(2) -replace '\\','/')

# Keep the scan output so the report generator can read it back.
$slug    = ($Site -replace '^https?://','' -replace '[^a-zA-Z0-9]+','-').Trim('-').ToLower()
$scanOut = Join-Path $env:TEMP "sitesentry-scan-$slug.txt"

Write-Host "Scanning $Site (read-only, public requests only)..." -ForegroundColor Cyan
& $bash -lc "cd '$agentUnix' && ./scripts/prospect-scan.sh '$Site'" 2>&1 | Tee-Object -FilePath $scanOut
$scanExit = $LASTEXITCODE

if ($scanExit -eq 2) {
  Write-Host ""
  Write-Warning "The scan could not reach the site, so nothing was checked. No report will be built."
  Write-Host "Open $Site in a browser to confirm whether it's genuinely down or the address is wrong."
  exit 2
}

if (-not $Report) {
  Write-Host ""
  Write-Host "Scan saved to: $scanOut" -ForegroundColor DarkGray
  Write-Host "To build the client report, re-run with -Report (plus -Business/-Name/-Plan/-Why)." -ForegroundColor DarkGray
  exit 0
}

# --- build the report -------------------------------------------------------
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js not found on PATH — needed to build the report. Install from https://nodejs.org" }

if (-not $Out) {
  $Out = Join-Path $agentDir "reports\$slug.html"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null

$argv = @(
  (Join-Path $PSScriptRoot 'make-report.mjs'),
  '--scan', $scanOut,
  '--site', $Site,
  '--out',  $Out
)
if ($Business) { $argv += @('--business', $Business) }
if ($Name)     { $argv += @('--name',     $Name) }
if ($Plan)     { $argv += @('--plan',     $Plan) }
if ($Why)      { $argv += @('--why',      $Why) }
if ($Concern)  { $argv += @('--concern',  $Concern) }

& node @argv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Report: $Out" -ForegroundColor Green
Write-Host "This is a DRAFT. Read it, then YOU send it — nothing goes to the prospect automatically." -ForegroundColor Yellow
Write-Host "Open it with:  start `"`" `"$Out`"" -ForegroundColor DarkGray
