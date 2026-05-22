#!/usr/bin/env bash
# One-shot installer for the TradingView MCP server (Mac / Linux).
# Idempotent — safe to re-run; pulls latest if already installed.
#
# Usage:
#   bash scripts/tradingview-mcp/install.sh
#       → installs to $HOME/tradingview-mcp-jackson (default)
#
#   bash scripts/tradingview-mcp/install.sh ~/Documents/agent-trading-view
#       → installs to the given directory
#
#   TARGET_DIR=~/Documents/agent-trading-view bash scripts/tradingview-mcp/install.sh
#       → same, via env var
set -euo pipefail

REPO_URL="https://github.com/LewisWJackson/tradingview-mcp-jackson.git"

# Resolve install dir: positional arg > env var > default.
INSTALL_DIR="${1:-${TARGET_DIR:-$HOME/tradingview-mcp-jackson}}"
# Expand ~ if user passed a literal "~/..." string
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
SERVER_PATH="$INSTALL_DIR/src/server.js"

echo "[info] target directory: $INSTALL_DIR"

# ----- 1. Node version check ----------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  echo "[error] Node.js not found. Install Node 18+ first: https://nodejs.org" >&2
  exit 1
fi
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "[error] Node $NODE_MAJOR detected. Need 18+." >&2
  exit 1
fi
echo "[ok] node $(node --version)"

# ----- 2. Clone or pull ---------------------------------------------------
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "[info] $INSTALL_DIR exists — pulling latest"
  git -C "$INSTALL_DIR" pull --ff-only
else
  # Ensure parent dir exists (e.g. ~/Documents)
  mkdir -p "$(dirname "$INSTALL_DIR")"
  echo "[info] cloning $REPO_URL -> $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# ----- 3. npm install -----------------------------------------------------
echo "[info] running npm install"
( cd "$INSTALL_DIR" && npm install )

# ----- 4. npm link (tv CLI on PATH) ---------------------------------------
echo "[info] linking 'tv' CLI globally"
if ! ( cd "$INSTALL_DIR" && npm link ); then
  echo "[warn] npm link failed. Retry manually with elevated privileges:"
  echo "       cd $INSTALL_DIR && sudo npm link"
fi

# ----- 5. rules.json ------------------------------------------------------
if [ ! -f "$INSTALL_DIR/rules.json" ]; then
  cp "$INSTALL_DIR/rules.example.json" "$INSTALL_DIR/rules.json"
  echo "[ok] created $INSTALL_DIR/rules.json — edit this to set your watchlist"
else
  echo "[ok] $INSTALL_DIR/rules.json already exists (left untouched)"
fi

# ----- 6. Print client registration snippets ------------------------------
cat <<EOF

================================================================
 Install complete at: $INSTALL_DIR
 Register the server with your Claude client(s):
================================================================

[A] Claude Code  — ~/.claude/.mcp.json  (merge into "mcpServers"):

{
  "mcpServers": {
    "tradingview": {
      "command": "node",
      "args": ["$SERVER_PATH"]
    }
  }
}

[B] Claude Desktop — same JSON snippet, in:
      Mac:   ~/Library/Application Support/Claude/claude_desktop_config.json
      Linux: ~/.config/Claude/claude_desktop_config.json
    Restart Claude Desktop after editing.

[C] Cursor — same JSON snippet, in ~/.cursor/mcp.json
    (or via UI: Settings -> Features -> MCP -> "Add new MCP server").

================================================================
 Next steps:
   1. Make sure TradingView Desktop is installed and you're signed in
      (the server reads whichever account is logged in on the desktop app).
   2. Launch TradingView with the CDP debug port:
        Mac:   $INSTALL_DIR/scripts/launch_tv_debug_mac.sh
        Linux: $INSTALL_DIR/scripts/launch_tv_debug_linux.sh
   3. Verify connection:
        tv status
      Expect: {"success": true, ..., "cdp_connected": true}
================================================================
EOF
