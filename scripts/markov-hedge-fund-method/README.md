# Markov Regime Trading Strategy — Setup & Best-Use Guide

**Purpose**: Install and use the [markov-hedge-fund-method](https://github.com/jackson-video-resources/markov-hedge-fund-method) Claude Code plugin. It quantifies the market as a 3-state Markov process — **Bull / Bear / Sideways** — builds a 3×3 transition matrix from price history, and emits a directional signal of `P(bull) − P(bear)`. Framework by Roan ([@RohOnChain](https://x.com/RohOnChain)); plugin and installer by Lewis Jackson.

This folder is documentation only. The plugin installs into Claude Code's plugin store; the working files live under `~/.claude/`.

---

## Prerequisites

- **Claude Code** (the CLI).
- No API keys or accounts required.
- Python dependencies resolve automatically via `uv` (PEP 723 inline metadata) on first run.
- Optional: `hmmlearn` (the skill gracefully degrades if it's missing — you get the threshold method but not the label-free HMM path).
- TradingView account (free tier is fine) — only needed if you want to render the Pine Script overlay.

---

## 1. Install the plugin

**Recommended — marketplace install:**

```
/plugin marketplace add jackson-video-resources/markov-hedge-fund-method
/plugin install markov-hedge-fund-method@markov-hedge-fund-method
```

Run these from Claude Code's slash-command bar.

**Alternative — transparent build:** paste the contents of [`markov-hedge-fund-method.md`](https://github.com/jackson-video-resources/markov-hedge-fund-method/blob/main/markov-hedge-fund-method.md) into Claude Code in agent mode and it will build the skill locally from scratch.

---

## 2. Verify

In Claude Code:

```
/markov-hedge-fund-method:regime
```

Or just ask in plain English — Claude will route to the `regime` skill automatically. Sample prompts the upstream documents:

- *"Detect the regime on BTC-USD."*
- *"Add a regime confirmation filter to my SPY momentum strategy."*
- *"What's the long-run regime mix of AAPL — is it too tail-heavy to trade?"*

---

## The mathematical core

The Markov property: the past doesn't matter, only the current state determines the probability of what comes next.

**Trailing 20-day return**: `R_20 = (P_t / P_{t-20}) - 1`.

**Regime labels** (defaults, configurable):

| State | Condition |
|---|---|
| Bull | `R_20 >= 0.05` |
| Bear | `R_20 <= -0.05` |
| Sideways | `-0.05 < R_20 < 0.05` |

**Transition matrix** — count every day-to-day transition between labelled states and normalise rows to probabilities:

```
        Bull   Bear   Side
Bull  [ p11   p12   p13 ]
Bear  [ p21   p22   p23 ]
Side  [ p31   p32   p33 ]
```

Where `p_ij` is the probability of transitioning from state `i` to state `j`.

**Multi-day forecast**: raise the matrix to the power of the forecast horizon — `P^n`. Beyond ~28 days the result collapses to the **stationary distribution**, which is why short-horizon edges fade.

**Signal**: `signal = P(bull) − P(bear)`. Positive = directional long bias, negative = short, near-zero = stand aside.

---

## What the skill computes

- Daily regime labels (Bull / Bear / Sideways).
- 3×3 transition matrix with n-step forecasting (`P^n`).
- Stationary distribution (baseline regime mix).
- Walk-forward backtest results (Sharpe ratio, max drawdown).
- Signed signal: `bull_prob − bear_prob`.

---

## End-to-end workflow

The 9-step method the skill automates:

1. **Pull close prices**, compute the 20-day trailing return.
2. **Label regimes** via the ±5% thresholds.
3. **Build the transition matrix** from day-to-day counts.
4. **Forecast tomorrow** by multiplying the matrix against the current state vector.
5. **Generate signal**: `P(bull) − P(bear)`.
6. **Walk-forward backtest** — re-estimate the matrix at every timestep using only prior data. This is the mathematical guard against lookahead bias.
7. **Optional — drop the ±5% labels**: switch to the Hidden Markov Model path (`hmmlearn`, Baum-Welch fit, Viterbi decoding) so the states are discovered from the raw return distribution rather than imposed.
8. **Automate via the skill** — the Claude Code agent runs the Python pipeline and structures the output.
9. **Deploy to TradingView** — paste the Pine Script overlay onto a chart to visualise regime shifts live.

---

## Best-use prompts

Paste any of these directly into Claude Code:

> Run the Markov pipeline on SPY for the last five years and show me the current regime probabilities plus the stationary distribution.

> Walk-forward backtest TSLA from 2020-01-01, compare the ±5% threshold method against the HMM path, and tell me which produced the lower max drawdown.

> Generate the Pine Script overlay for QQQ's current transition matrix and show me how to paste it into TradingView.

> Add a regime confirmation filter to an existing SPY momentum strategy — only take longs when `P(bull) - P(bear) > 0.2`.

---

## Pine Script indicator

The repo ships a TradingView v5 indicator at [`pine-script/markov-hedge-fund-method.pine`](https://github.com/jackson-video-resources/markov-hedge-fund-method/blob/main/pine-script/markov-hedge-fund-method.pine).

**To use manually**: TradingView → Pine Editor → paste the `.pine` file → Save → Add to Chart.

Configurable inputs: lookback window (default 20), Bull / Bear thresholds (default ±5%), table toggles. The overlay paints a regime ribbon, the live 3×3 transition matrix in the corner, the stationary-distribution table, and a current-regime banner.

**To use automatically**: see the **See also** section — the TradingView MCP server can deploy the Pine Script into your chart without copy-paste.

---

## Caveats

- A backtest is not a live track record. Walk-forward is the right diagnostic — but slippage, fills and regime shifts in unseen data can still hurt.
- Forecast horizons beyond ~28 days converge to the stationary distribution. Treat the matrix as a short-horizon nowcaster, not a long-range oracle.
- The ±5% / 20-day defaults are sensible starting points, **not asset-specific**. BTC and bond ETFs need different thresholds. Re-tune per asset before trusting the labels.
- The HMM path removes the threshold subjectivity but introduces initialisation sensitivity (random seed, number of states). Run multiple seeds and check convergence.

---

## Resources

- Upstream repo: https://github.com/jackson-video-resources/markov-hedge-fund-method
- Framework author: [Roan (@RohOnChain)](https://x.com/RohOnChain)
- Plugin author: [Lewis Jackson](https://github.com/LewisWJackson)
- `hmmlearn` docs: https://hmmlearn.readthedocs.io/
- Claude Code plugin docs: https://docs.claude.com/en/docs/claude-code

**License**: MIT.

---

## See also

[`scripts/tradingview-mcp/README.md`](../tradingview-mcp/README.md) — the TradingView MCP server. Natural pairing: this skill is the **brain** (generates regime signals and a Pine Script overlay), the MCP server is the **hands** (deploys that Pine Script into TradingView via `pine_set_source` → `pine_smart_compile` → `pine_save`, and reads back rendered values). Install both for a single end-to-end loop:

```
Markov skill: "Generate a regime overlay for QQQ."
        │
        ▼  (Pine source text)
TradingView MCP: pine_set_source → pine_smart_compile → pine_save
        │
        ▼  (rendered chart)
TradingView MCP: chart_get_state → data_get_study_values
        │
        ▼  (live regime values)
Markov skill: walk-forward backtest, signal, position sizing
```
