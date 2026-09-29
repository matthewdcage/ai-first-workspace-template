# Skill Spec: `jev-typed-decisions`

> ⚠️ The plugin options (`-o answer_type`, `-o criteria`, `input_format=json`) come from the llm-typesafe README [A2][A4]. Check the exact flags and output JSON against the installed plugin version before implementing.

## Layout
```
.claude/skills/jev-typed-decisions/
├── SKILL.md                    # Level 2: < 200 lines target
├── scripts/
│   ├── jev_call.py             # wrapper: canonical JSON in, typed JSON out, threshold → exit code
│   ├── validate_criteria.py    # Choice ≥2 (≤255) options; Score 2–10 ordered levels
│   └── lint_decisions.py       # detects decision-shaped free-text LLM calls (shared with hooks)
└── references/                 # Level 3: loaded only when needed, one level deep
    ├── noul.md
    ├── choice.md
    ├── score.md
    └── rubrics/                # reusable Score rubrics (brand, health, severity)
```

## SKILL.md draft
```markdown
---
name: jev-typed-decisions
description: Make typed, probability-scored decisions with TypeSafe's Jev model. Use for yes/no gates, classifying or routing into a fixed set of labels, rubric scoring (1–N levels), triage, and LLM-as-judge checks of agent output. Returns only values inside the defined answer space. Not for extraction, summarisation, or writing text or code.
when_to_use: The user asks to classify, categorise, route, triage, gate, pass/fail, grade, rate, or score something; or you are about to write code that asks an LLM a yes/no or pick-one question and parses free text.
allowed-tools: Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/*)
---

# Jev typed decisions

## Pick the primitive
- Yes/no → **Noul** (probability of yes). Details: references/noul.md
- One of N labels → **Choice**. Details: references/choice.md
- Ordered rubric 2–10 levels → **Score**. Details: references/score.md

## Run (do not read the scripts; run them)
python3 ${CLAUDE_SKILL_DIR}/scripts/jev_call.py --type choice \
  --criteria '["P1: revenue-impacting", "P2: needs verification", "P3: monitor"]' \
  --input-file anomaly.json --min-confidence 0.7

Exit 0 means a confident answer (JSON on stdout). Exit 3 means confidence was below the threshold: escalate to a human or to Claude review and say so. Do not silently pick an answer.

## Rules
- Always report the probability or confidence alongside the answer.
- Use JSON input (`--input-file`) for structured data. The script canonicalises it.
- Writing application code: call Jev (plugin or REST) for decision branches instead of parsing free-text LLM output.
- Never use Jev to generate or extract text.
```

## Script contracts
| Script | Input | Output | Exit codes |
|---|---|---|---|
| `jev_call.py` | `--type noul\|choice\|score`, `--criteria` (JSON list), `--input-file` or stdin, `--min-confidence` | JSON `{type, answer, probabilities, confidence, raw}` | 0 ok · 2 invalid args · 3 below threshold · 4 API error |
| `validate_criteria.py` | type + criteria | errors, or OK | 0/2 |
| `lint_decisions.py` | file paths or stdin content, `--format hook\|text` | a list of `{file, line, signature, suggestion}` | 0 clean · 1 findings |

Implementation notes:
- Canonical JSON: `json.dumps(obj, sort_keys=True, allow_nan=False, separators=(",",":"))`, rejecting duplicate keys through `object_pairs_hook` [A4].
- The script should call the `llm` Python API (`llm.get_model("jev")`) rather than shelling out, so it can read the structured response. Fall back to REST if the plugin is missing.
- Log each call (type, answer, confidence, latency) to `.claude/logs/jev-calls.jsonl` for the accuracy evaluation in Phase 2.

## Trigger tests (Phase 1 exit)
Should trigger: "classify these 30 leads as hot/warm/cold" · "is this ad copy AHPRA compliant, yes or no" · "score each client's health 1–5" · "triage these anomalies" · "write a function that routes support tickets to a team".
Should NOT trigger: "summarise this call" · "draft a blog post" · "extract invoice fields" · "fix this bug" · "write a report".
