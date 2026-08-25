<#
.SYNOPSIS
  Pulls the Steadyline repo and copies the EA into your MT5 data folder.

.DESCRIPTION
  Clones the repo on first run, or pulls latest on later runs, then copies
  MQL5/Experts, MQL5/Include/Steadyline, and MQL5/Presets into your
  MetaTrader 5 terminal's data folder (auto-detected under
  %APPDATA%\MetaQuotes\Terminal when possible).

.PARAMETER RepoUrl
  Git URL of the repo. Defaults to the Steadyline GitHub repo.

.PARAMETER Branch
  Branch to check out. Defaults to the current development branch, since
  the EA lives there until it's merged to main.

.PARAMETER RepoPath
  Local folder to clone/pull into. Defaults to $HOME\Steadyline.

.PARAMETER DataFolder
  MT5 data folder to install into. If omitted, auto-detected. If more than
  one terminal install is found, pass this explicitly -- get the exact
  path from MT5 via File > Open Data Folder.

.EXAMPLE
  .\install-mt5.ps1

.EXAMPLE
  .\install-mt5.ps1 -DataFolder "C:\Users\me\AppData\Roaming\MetaQuotes\Terminal\ABCDEF123..."
#>
param(
    [string]$RepoUrl = "https://github.com/robnye0-tech/Steadyline.git",
    [string]$Branch = "claude/metatrader5-gold-trading-0etqts",
    [string]$RepoPath = "$HOME\Steadyline",
    [string]$DataFolder
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or not on PATH. Install it first: winget install --id Git.Git -e"
}

# 1. Clone or update the repo, on the target branch
if (Test-Path (Join-Path $RepoPath ".git")) {
    Write-Host "Updating existing repo at $RepoPath (branch $Branch)..."
    git -C $RepoPath fetch origin $Branch
    git -C $RepoPath checkout $Branch
    git -C $RepoPath pull origin $Branch
} else {
    Write-Host "Cloning repo to $RepoPath (branch $Branch)..."
    git clone --branch $Branch $RepoUrl $RepoPath
}

# 2. Locate the MT5 data folder if not given
if (-not $DataFolder) {
    $root = Join-Path $env:APPDATA "MetaQuotes\Terminal"
    if (-not (Test-Path $root)) {
        throw "Couldn't find $root. Open MT5 > File > Open Data Folder, copy that path, and re-run with -DataFolder '<path>'."
    }

    $candidates = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "MQL5") }

    if (-not $candidates -or $candidates.Count -eq 0) {
        throw "No MT5 data folder with an MQL5 subfolder found under $root. Open MT5 > File > Open Data Folder, copy that path, and re-run with -DataFolder '<path>'."
    } elseif ($candidates.Count -gt 1) {
        Write-Host "Multiple MT5 installs found:"
        $candidates | ForEach-Object { Write-Host "  $($_.FullName)" }
        throw "Re-run with -DataFolder '<one of the paths above>' to disambiguate."
    } else {
        $DataFolder = $candidates[0].FullName
    }
}

Write-Host "Using MT5 data folder: $DataFolder"

# 3. Copy files into place
$mql5Src = Join-Path $RepoPath "MQL5"
$mql5Dst = Join-Path $DataFolder "MQL5"

foreach ($sub in @("Experts", "Include", "Presets")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $mql5Dst $sub) | Out-Null
}

Copy-Item -Path (Join-Path $mql5Src "Experts\*")             -Destination (Join-Path $mql5Dst "Experts")  -Recurse -Force
Copy-Item -Path (Join-Path $mql5Src "Include\Steadyline")    -Destination (Join-Path $mql5Dst "Include")  -Recurse -Force
Copy-Item -Path (Join-Path $mql5Src "Presets\*")             -Destination (Join-Path $mql5Dst "Presets")  -Recurse -Force

Write-Host ""
Write-Host "Done. Next steps in MT5:"
Write-Host "  1. Open MetaEditor, compile Experts\SteadylineScalperEA.mq5 (F7)."
Write-Host "  2. In MT5, open a EURUSD chart."
Write-Host "  3. Enable the AutoTrading button in the toolbar."
Write-Host "  4. Drag SteadylineScalperEA from Navigator > Expert Advisors onto the chart."
Write-Host "  5. In the dialog: Common tab -> check 'Allow Algo Trading'; Inputs tab -> Load -> Presets\SteadylineScalperEA.set."
