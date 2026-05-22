# One-shot installer for the TradingView MCP server (Windows).
# Idempotent - safe to re-run; pulls latest if already installed.
#
# Usage:
#   .\scripts\tradingview-mcp\install.ps1
#       Installs to %USERPROFILE%\tradingview-mcp-jackson (default)
#
#   .\scripts\tradingview-mcp\install.ps1 -TargetDir "$env:USERPROFILE\Documents\agent-trading-view"
#       Installs to the given directory.

param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE 'tradingview-mcp-jackson')
)

$ErrorActionPreference = 'Stop'

$RepoUrl    = 'https://github.com/LewisWJackson/tradingview-mcp-jackson.git'
$InstallDir = $TargetDir
$ServerPath = Join-Path $InstallDir 'src\server.js'
# JSON requires double-escaped backslashes
$JsonPath   = $ServerPath -replace '\\', '\\'

Write-Host "[info] target directory: $InstallDir"

# ----- 1. Node version check ---------------------------------------------
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js not found. Install Node 18+ first: https://nodejs.org"
    exit 1
}
$nodeMajor = [int](node -p 'process.versions.node.split(".")[0]')
if ($nodeMajor -lt 18) {
    Write-Error "Node $nodeMajor detected. Need 18+."
    exit 1
}
Write-Host "[ok] node $(node --version)"

# ----- 2. Clone or pull --------------------------------------------------
if (Test-Path (Join-Path $InstallDir '.git')) {
    Write-Host "[info] $InstallDir exists - pulling latest"
    git -C $InstallDir pull --ff-only
} else {
    $parent = Split-Path -Parent $InstallDir
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-Host "[info] cloning $RepoUrl -> $InstallDir"
    git clone $RepoUrl $InstallDir
}

# ----- 3. npm install ----------------------------------------------------
Write-Host "[info] running npm install"
Push-Location $InstallDir
try { npm install } finally { Pop-Location }

# ----- 4. npm link (tv CLI on PATH) --------------------------------------
Write-Host "[info] linking 'tv' CLI globally"
Push-Location $InstallDir
try {
    npm link
} catch {
    Write-Warning "npm link failed. Retry from an elevated PowerShell:"
    Write-Warning "  cd $InstallDir; npm link"
} finally { Pop-Location }

# ----- 5. rules.json -----------------------------------------------------
$RulesPath = Join-Path $InstallDir 'rules.json'
if (-not (Test-Path $RulesPath)) {
    Copy-Item (Join-Path $InstallDir 'rules.example.json') $RulesPath
    Write-Host "[ok] created $RulesPath - edit this to set your watchlist"
} else {
    Write-Host "[ok] $RulesPath already exists (left untouched)"
}

# ----- 6. Print client registration snippets -----------------------------
@"

================================================================
 Install complete at: $InstallDir
 Register the server with your Claude client(s):
================================================================

[A] Claude Code  - %USERPROFILE%\.claude\.mcp.json  (merge into "mcpServers"):

{
  "mcpServers": {
    "tradingview": {
      "command": "node",
      "args": ["$JsonPath"]
    }
  }
}

[B] Claude Desktop - same JSON snippet, in:
      %APPDATA%\Claude\claude_desktop_config.json
    Restart Claude Desktop after editing.

[C] Cursor - same JSON snippet, in %USERPROFILE%\.cursor\mcp.json
    (or via UI: Settings -> Features -> MCP -> "Add new MCP server").

================================================================
 Next steps:
   1. Make sure TradingView Desktop is installed and you're signed in
      (the server reads whichever account is logged in on the desktop app).
   2. Launch TradingView with the CDP debug port:
        $InstallDir\scripts\launch_tv_debug.bat
   3. Verify connection:
        tv status
      Expect: {"success": true, ..., "cdp_connected": true}
================================================================
"@ | Write-Host
