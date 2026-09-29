# Integration Plan: Jev in Claude Code

Cross-references: findings are cited as `[A1]`, `[C1]` and so on, pointing to `01-research-report.md`.

## Guiding principle: route decisions to Jev, not generation

| Task shape | Use Jev? | Otherwise |
|---|---|---|
| Yes/no gate ("is this PII?", "does this pass brand rules?") | ✅ **Noul** | — |
| Pick one label or route from a fixed set | ✅ **Choice** | — |
| Grade against an ordered rubric (quality, severity, health 1–5) | ✅ **Score** | — |
| LLM-as-judge on agent output | ✅ Score/Noul | — |
| Extract fields, summarise, write copy, generate code | ❌ | Claude + schema validation (Pydantic / JSON Schema / structured outputs) |

Jev never generates text [A1], and its type guarantee covers only the shape of the answer, not its correctness [A3]. **Enforcement must therefore target *decision-shaped* LLM calls only.** Blocking "all untyped LLM calls" would be wrong and disruptive.

## Architecture: three layers

```
 Layer 1  KNOWLEDGE   skill: jev-typed-decisions (SKILL.md + scripts + references)   ← how
 Layer 2  INTENT      CLAUDE.md rule + UserPromptSubmit/SessionStart nudge         ← when (advisory)
 Layer 3  GUARANTEE   PreToolUse (Write|Edit|Bash) + Stop backstop hooks           ← must (deterministic)
 Packaging: a single plugin (skill + hooks/hooks.json) for portability         [C3]
```

## Phase 0: Prerequisites (≈0.5 day)
- [ ] Get TypeSafe early-access credentials. Store the key as an environment variable (`TYPESAFE_API_KEY` or whatever the plugin expects), never in the repo.
- [ ] `pip install llm && llm install llm-typesafe`. Smoke test: `llm -m jev "Is the sky green?"`.
- [ ] Check the REST contract against docs.typesafe.ai (it was unreachable during research, see `05`).
- [ ] Cloud sessions: add the key to the environment secrets and allow `api.typesafe.ai` in the network policy.

**Exit:** a successful Noul, Choice and Score call from the shell.

## Phase 1: The `jev-typed-decisions` skill (≈1–2 days)
Full specification: `03-skill-spec.md`.
- Put it at `.claude/skills/jev-typed-decisions/` in this repo, so it is versioned with the workspace.
- Description leads with the triggers: classify, route, gate, score, judge [B2].
- Scripts do all the deterministic work [B3]: `jev_call.py` (a wrapper that serialises JSON canonically [A4] and validates criteria counts [A2]), `validate_criteria.py`, and `lint_decisions.py` (shared with the hooks).
- References for each primitive: `references/noul.md`, `choice.md`, `score.md` [B1].

**Exit:** in 5 test prompts that are decision-shaped, the skill triggers on its own and produces a valid Jev call. In 5 generation prompts, it does *not* trigger.

## Phase 2: Deep integrations for specific use cases (≈1 day each; pick by value)
Candidates are drawn from this workspace's existing skills and workflows. Each one is a separate script or section inside the skill, or a small companion skill.

| # | Use case | Primitive | Integration point |
|---|---|---|---|
| 2a | **Brand-review gate PASS/FAIL** (e.g. `hydra-brand-review-gate`) | Noul per rule, plus an aggregate | The existing skill calls `jev_call.py` for each rule. The JSON verdict carries probabilities. A threshold (for example p<0.3 means FAIL) is written in config |
| 2b | **Anomaly triage P1/P2/P3** (`hydra-anomaly-brief`) | Choice | Classify each anomaly before Claude writes the brief. Confidence below the threshold goes to CHECK |
| 2c | **Client health 1–5** (`hydra-client-health`) | Score (5 levels) | One Score call per sub-dimension, with the rubric in `references/score.md` |
| 2d | **Inbox/ticket routing** (sales calls, hiring screening) | Choice | For example the hiring screening agent in `Docs/Operations/Hiring/...` routes a candidate to Strong/Average/Weak |
| 2e | **LLM-as-judge on agent output** | Score/Noul | A Stop hook or subagent grades a deliverable against its rubric before it is marked done |
| 2f | **Code that calls LLMs for decisions** | any | Claude writes app code that calls Jev (or the REST API) instead of a free-text LLM call that gets parsed |

**Exit per use case:** on 20 or more labelled examples, Jev's accuracy is ≥ the current Claude-based decision (see open question Q4 in `05`). **Only use cases that pass get enforcement in Phase 3.**

## Phase 3: Enforcement hooks (≈2 days plus a soak period)
Full specification: `04-hooks-spec.md`. Roll out in three modes:
1. **Warn** (2 weeks): PreToolUse returns `additionalContext` only [C2]. Log each hit to `.claude/logs/jev-hook.jsonl`.
2. **Ask**: `permissionDecision: "ask"` for high-confidence matches, so a human confirms [C1].
3. **Deny**: `permissionDecision: "deny"` with a steering reason, only for the signatures whose false-positive rate is under 5% during Warn mode.

Hook coverage:
- `UserPromptSubmit`: a cheap keyword check ("classify", "score", "triage", "pass/fail", "route") adds a nudge: "consider the jev-typed-decisions skill" [C2].
- `PreToolUse` on `Write|Edit|MultiEdit`: lint the incoming content for decision-shaped LLM calls [C1].
- `PreToolUse` on `Bash`: the same lint on heredoc/redirect writes, because Write|Edit hooks miss these [C4].
- `Stop`: run `lint_decisions.py` over `git diff --name-only`. If there are violations, block the stop so Claude keeps working [C2]. This is the backstop.

**Exit:** during Deny mode, a false-positive rate under 5% over 2 weeks, and a test proving that hooks fire inside subagents (see `05`).

## Phase 4: Package and distribute (≈0.5 day)
- Wrap the skill and `hooks/hooks.json` as a plugin (paths use `${CLAUDE_PLUGIN_ROOT}`) [B3][C3], so it works in other repos and cloud sessions.
- Add a short rule to a root `CLAUDE.md` (the repo has none yet; mirror it in `.cursorrules`). It stays advisory [B4]:
  > For yes/no gates, classification, routing, or rubric scoring, use the `jev-typed-decisions` skill instead of free-text LLM calls. Do not use Jev for extraction or generation.

## Effort & sequencing summary
| Phase | Effort | Depends on |
|---|---|---|
| 0 Prereqs | 0.5d | API access |
| 1 Skill | 1–2d | 0 |
| 2 Use cases | ~1d each | 1 |
| 3 Hooks | 2d + 2–4 wk soak | 1, and 2 for the use cases that pass |
| 4 Plugin | 0.5d | 3 |
