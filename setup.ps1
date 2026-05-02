# Mirror this Brain Bridge web dev environment on a fresh Windows machine.
# Usage:  .\setup.ps1            install deps only
#         .\setup.ps1 -Run       install deps and start dev server
[CmdletBinding()]
param(
  [switch]$Run
)

$ErrorActionPreference = 'Stop'
$RequiredNodeMajor = 18

function Require-Cmd($name, $hint) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: $name not found. $hint" -ForegroundColor Red
    exit 1
  }
}

Require-Cmd 'node' 'Install Node.js 18+ from https://nodejs.org/'
Require-Cmd 'npm'  'npm should ship with Node.js.'

$nodeVersion = (& node --version).TrimStart('v')
$nodeMajor   = [int]($nodeVersion.Split('.')[0])
if ($nodeMajor -lt $RequiredNodeMajor) {
  Write-Host "ERROR: Node $RequiredNodeMajor+ required, found v$nodeVersion" -ForegroundColor Red
  exit 1
}

Write-Host "Node v$nodeVersion / npm $(& npm --version) detected."
Write-Host "Installing site dependencies (this can take a minute)..."
& npm install
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path 'cdk') {
  Write-Host "Installing CDK dependencies (optional, only needed for AWS deploys)..."
  Push-Location cdk
  try { & npm install } catch { Write-Host "WARN: cdk install failed; fine if you only run the site locally." -ForegroundColor Yellow }
  Pop-Location
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Start the dev server with: npm run dev"
Write-Host "It will be available at: http://localhost:4321/"

if ($Run) {
  Write-Host ""
  Write-Host "Starting dev server..."
  & npm run dev
}
