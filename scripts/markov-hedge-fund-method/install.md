# Quick install — Markov Hedge Fund Method

The full [README.md](README.md) has the math and best-use prompts; this file is just the install crib-sheet.

## One-shot path (recommended)

Open Claude Code and run these two slash commands in order:

```
/plugin marketplace add jackson-video-resources/markov-hedge-fund-method
/plugin install markov-hedge-fund-method@markov-hedge-fund-method
```

No API keys, no `pip install`, no sudo. Python deps resolve automatically via `uv` (PEP 723 inline metadata) on first run.

## Verify

Still in Claude Code:

```
/markov-hedge-fund-method:regime
```

Or just type plain English — Claude will route to the `regime` skill automatically:

> Detect the regime on SPY.

Expected output: a Bull / Bear / Sideways label for today plus next-day transition probabilities.

## Transparent path (build it from the prompt)

If you want to inspect the skill source before letting Claude install anything, paste the contents of [`markov-hedge-fund-method.md`](https://github.com/jackson-video-resources/markov-hedge-fund-method/blob/main/markov-hedge-fund-method.md) into Claude Code in agent mode. The agent will build the skill locally from scratch, file by file, so you can read and amend each step.

## Optional — enable the HMM path

```
pip install hmmlearn
```

Unlocks the label-free Hidden Markov Model path (Baum-Welch fit, Viterbi decoding) so the regimes are discovered from the raw return distribution rather than imposed by the ±5% thresholds. Without `hmmlearn`, the skill gracefully falls back to the threshold method.

## See also

For installing the TradingView MCP server so the Pine Script overlay can be deployed onto your chart automatically (instead of copy-pasting from the Pine Editor), see [`../tradingview-mcp/README.md`](../tradingview-mcp/README.md) and the one-shot installer alongside it (`install.sh` for Mac/Linux, `install.ps1` for Windows).
