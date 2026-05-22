# TradingView MCP — Setup & Best-Use Guide

**Purpose**: Give Claude live read/write access to your TradingView Desktop charts via the [tradingview-mcp-jackson](https://github.com/LewisWJackson/tradingview-mcp-jackson) MCP server. No external API, no scraping — communicates locally over Chrome DevTools Protocol (CDP). Exposes 81 MCP tools (chart reading, indicator values, Pine Script dev loop, replay mode, morning brief automation).

This folder is documentation only. The MCP server itself lives in your home directory (`~/tradingview-mcp-jackson`).

---

## Prerequisites

- **TradingView Desktop app** with a paid subscription (real-time data requires it).
- **Node.js 18+**.
- One of: **Claude Code**, **Claude Desktop**, or **Cursor** (this workspace's primary editor — see `README.md:445-450`).
- **macOS, Windows, or Linux**.

---

## Fast path — one-shot installer

If you just want it working:

**Mac / Linux:**
```bash
bash scripts/tradingview-mcp/install.sh
```

**Windows:**
```powershell
.\scripts\tradingview-mcp\install.ps1
```

The installer clones the server to `~/tradingview-mcp-jackson`, runs `npm install` and `npm link`, copies `rules.example.json` to `rules.json` if needed, and prints pre-filled MCP registration snippets for all three clients (Claude Code, Claude Desktop, Cursor). Idempotent — safe to re-run; pulls latest if the repo's already there.

If you'd rather do it manually, continue with steps 1-5 below.

---

## 1. Install the server (manual)

```bash
git clone https://github.com/LewisWJackson/tradingview-mcp-jackson.git ~/tradingview-mcp-jackson
cd ~/tradingview-mcp-jackson
npm install
```

Optional — enable the `tv` CLI globally:

```bash
npm link
```

---

## 2. Launch TradingView with the CDP debug port

The server connects to TradingView Desktop via Chrome DevTools Protocol on port 9222. You must launch TradingView with that port exposed.

**macOS:**
```bash
~/tradingview-mcp-jackson/scripts/launch_tv_debug_mac.sh
```

**Windows:**
```bat
%USERPROFILE%\tradingview-mcp-jackson\scripts\launch_tv_debug.bat
```

**Linux:**
```bash
~/tradingview-mcp-jackson/scripts/launch_tv_debug_linux.sh
```

Inside Claude you can also call the equivalent MCP tool: *"Use `tv_launch` to start TradingView with debugging enabled."*

---

## 3. Register the server with your Claude client

The MCP server is a stdio process — the same JSON snippet works for all three clients; only the config file location changes.

### Claude Code

Add to `~/.claude/.mcp.json` (merge with existing `mcpServers`):

```json
{
  "mcpServers": {
    "tradingview": {
      "command": "node",
      "args": ["/Users/YOUR_USERNAME/tradingview-mcp-jackson/src/server.js"]
    }
  }
}
```

Resolve your username with `echo $USER` (Mac/Linux) or `echo %USERNAME%` (Windows). Path variants:

- **Mac**: `/Users/YOUR_USERNAME/tradingview-mcp-jackson/src/server.js`
- **Linux**: `/home/YOUR_USERNAME/tradingview-mcp-jackson/src/server.js`
- **Windows**: `C:\\Users\\YOUR_USERNAME\\tradingview-mcp-jackson\\src\\server.js`

### Claude Desktop

Same snippet, in `claude_desktop_config.json`:

- **Mac**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

Restart Claude Desktop after editing.

### Cursor

- **Settings UI**: Cursor → Settings → Features → MCP → "Add new MCP server" → paste the snippet's `tradingview` entry.
- **Or directly**: edit `~/.cursor/mcp.json` (or the project-level `.cursor/mcp.json`) with the same snippet.

---

## 4. Verify

CLI check (requires `npm link`):

```bash
tv status
```

Returns a JSON object. On success: `{"success": true, ...}` with `cdp_connected: true`. On failure (e.g. TradingView not running): `{"success": false, "error": "CDP connection failed after 5 attempts: fetch failed"}` — see Troubleshooting below.

In-Claude check — paste:

> Use `tv_health_check` to confirm the MCP connection.

---

## 5. Configure `rules.json`

```bash
cd ~/tradingview-mcp-jackson
cp rules.example.json rules.json
```

Edit `rules.json` to set your watchlist, bias criteria (bullish / bearish / neutral conditions) and session validation rules. This file drives the `morning_brief` workflow.

---

## Best-use workflows

Four workflows the upstream README documents. Paste these directly into Claude.

### Morning brief

> Run `morning_brief` and give me my session bias.

Or from the CLI: `tv brief`.

### Chart reading

> What's on my chart? Read the state, the active indicators and the current quote.

Internally: `chart_get_state` → `data_get_study_values` → `quote_get`.

### Pine Script development loop

> Write a Pine Script that <describe strategy>. Inject it, compile it, fix any errors, then save it.

Internally: `pine_set_source` → `pine_smart_compile` → `pine_get_errors` → `pine_get_console` → `pine_save`. This is the handoff target for the Markov skill (see **See also** below).

### Replay-mode practice

> Start replay at 2024-03-01 on SPY, step forward five bars at a time, and log my hypothetical entries.

Internally: `replay_start` → `replay_step` → `replay_trade` → `replay_status` → `replay_stop`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `CDP connection failed after N attempts: fetch failed` | TradingView isn't running with `--remote-debugging-port=9222`. Re-launch via the script in step 2. |
| `cdp_connected: false` | Same root cause — TradingView started without the CDP port. |
| `ECONNREFUSED` | TradingView not running, or port 9222 is blocked by a firewall. |
| MCP server missing from Claude's tool list | Check `~/.claude/.mcp.json` (or the equivalent for Desktop / Cursor) is valid JSON and restart the client. |
| `tv` command not found | Run `npm link` from `~/tradingview-mcp-jackson`. |
| `No rules.json found` | Run `cp rules.example.json rules.json` in the project root and configure it. |

---

## Caveats

- The server uses Chrome DevTools Protocol — a standard debugging interface. It does not reverse-engineer proprietary protocols or bypass access controls. Users are responsible for compliance with [TradingView's Terms of Use](https://www.tradingview.com/policies/).
- MIT license applies to the server's source code only — not to TradingView software, data, or trademarks.
- This is a personal-workflow tool, not a brokerage integration. It cannot place real orders.

---

## Where things live

| | Path |
|---|---|
| Server clone | `~/tradingview-mcp-jackson` |
| Rules file | `~/tradingview-mcp-jackson/rules.json` |
| Sessions cache | `~/.tradingview-mcp/sessions/` |
| Upstream repo | https://github.com/LewisWJackson/tradingview-mcp-jackson |

---

## See also

[`scripts/markov-hedge-fund-method/README.md`](../markov-hedge-fund-method/README.md) — the Markov Regime quant skill. Natural pairing: the Markov skill is the **brain** (generates regime signals and a Pine Script overlay), this MCP server is the **hands** (deploys that Pine Script into TradingView via `pine_set_source` → `pine_smart_compile` → `pine_save`, and reads back rendered values). Install both for an end-to-end "detect regime → render on chart → backtest in replay mode" loop.
