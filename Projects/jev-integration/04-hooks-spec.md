# Hooks Spec: Enforcing Jev Where It Fits

Semantics [C1]: to steer, use **exit 0 with JSON** and `permissionDecision` plus a reason. Use **exit 2** only for hard blocks. **Exit 1 does not block.** A PostToolUse block is only feedback [C2].

## 1. Detection signatures (`lint_decisions.py`)
Flag a *decision-shaped* LLM call only when **both** of these hold:
- **(a) An LLM call:** `anthropic.*messages.create`, `client.messages.create`, `openai.*chat.completions.create`, `responses.create`, `ChatOpenAI(`, `ChatAnthropic(`, `llm.get_model(`…`.prompt(` **with a model other than jev**, `generateText(`, `generateObject(`
- **(b) A decision-shaped context within about 15 lines:**
  - the prompt text asks "yes or no", "true/false", "answer with one of", "classify", "categorize", "which of the following", "rate from 1 to", "score 1-", "PASS or FAIL"
  - or the result is parsed as a decision: `.strip().lower() == "yes"`, `in ["yes","no"]`, `if "PASS" in`, `int(response...)` next to a rubric, `Literal[...]` / `enum` with 2–10 members as the response schema

It does **not** flag calls whose schema has free-text fields, extraction or summarisation prompts, or files under `tests/` or `fixtures/`, or lines with a `# jev: ignore` pragma (the escape hatch).

Expect false positives and negatives from regex and heuristics, and remember that Edit hooks see only fragments [C1]. That is why the Stop backstop scans whole files.

## 2. Configuration (`.claude/settings.json`, later the plugin's `hooks/hooks.json`)
```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/skills/jev-typed-decisions/scripts/lint_decisions.py --mode prompt-nudge" }] }
    ],
    "PreToolUse": [
      { "matcher": "Write|Edit|MultiEdit",
        "hooks": [{ "type": "command",
          "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/skills/jev-typed-decisions/scripts/lint_decisions.py --mode pretool --enforce \"${JEV_ENFORCE:-warn}\"" }] },
      { "matcher": "Bash",
        "hooks": [{ "type": "command",
          "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/skills/jev-typed-decisions/scripts/lint_decisions.py --mode pretool-bash --enforce \"${JEV_ENFORCE:-warn}\"" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/skills/jev-typed-decisions/scripts/lint_decisions.py --mode stop-diff --enforce \"${JEV_ENFORCE:-warn}\"" }] }
    ]
  }
}
```
`JEV_ENFORCE` = `warn` | `ask` | `deny`. You change the mode by changing an environment variable, not code.

## 3. Hook outputs per mode (stdout JSON, exit 0)
**Warn (PreToolUse):**
```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse",
  "additionalContext":"jev-lint: line 42 asks an LLM a yes/no question and parses free text. Consider the jev-typed-decisions skill (Noul) for a typed probability. Add `# jev: ignore` if this is intentional."}}
```
**Ask:** the same, plus `"permissionDecision":"ask","permissionDecisionReason":"<same text>"`.
**Deny:** `"permissionDecision":"deny","permissionDecisionReason":"Decision-shaped free-text LLM call. Rewrite using Jev (Noul/Choice/Score) via the jev-typed-decisions skill, or add '# jev: ignore <reason>'."` Claude reads the reason and rewrites the call [C1].

**UserPromptSubmit nudge:** only `additionalContext` ("This looks like a classification/scoring task; the jev-typed-decisions skill applies."). It never blocks.

**Stop backstop:** lint `git diff --name-only HEAD` plus untracked files. In `deny` mode, when there are findings, output `{"decision":"block","reason":"jev-lint found N untyped decision calls: …"}` so Claude keeps working [C2]. To avoid a loop, it reads `stop_hook_active` from the input and allows the stop if a block has already happened this turn.

## 4. Bash-path coverage [C4]
In `pretool-bash` mode, parse `tool_input.command` for `cat > file <<EOF`, `tee`, `>`/`>>`, `sed -i`, `python -c "open(...).write"`, and lint the embedded content. Anything missed here is caught by the Stop backstop.

## 5. Logging & rollout
Each hit is appended to `.claude/logs/jev-hook.jsonl` as `{ts, mode, signature, file, decision, overridden}`, and `.claude/logs/` goes into `.gitignore`. Review weekly and promote a signature to `deny` only when its false-positive rate is under 5%.

## 6. Tests (must pass before `ask`/`deny`)
- Fixtures in `scripts/tests/fixtures/{positive,negative}/*.py|ts` and a pytest suite for `lint_decisions.py`.
- Pipe hook-input JSON samples into each mode and assert the stdout JSON and exit code.
- Subagent test: spawn a subagent that writes a positive fixture and confirm the PreToolUse hook fires (see Q3 in `05`).
- Bash test: `cat > x.py <<EOF` with a positive fixture should trigger the Bash matcher or the Stop backstop.
