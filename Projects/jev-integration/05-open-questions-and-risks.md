# Open Questions, Risks & Decision Log

## Open questions (resolve before the phase noted)
| # | Question | Blocks | How to resolve |
|---|---|---|---|
| Q1 | Official SDKs and API contract: auth, pricing, rate limits, latency, the Python/TS client. Is there a Pydantic AI or LangChain integration to wrap instead of the `llm` CLI? | Phase 0/1 | Read docs.typesafe.ai (unreachable during research) |
| Q2 | Which detection signatures reliably separate decision-shaped calls from generation or extraction calls, across the Anthropic, OpenAI and LangChain SDKs? | Phase 3 ask/deny | Collect data during warn mode; review the fixture corpus |
| Q3 | Do project, plugin and skill-frontmatter PreToolUse/PostToolUse hooks fire for tool calls made inside **subagents** in the current Claude Code version? (The claim that they bypass hooks was refuted 0–3, but this is untested.) | Phase 3 exit | Subagent test in `04-hooks-spec.md` §6 |
| Q4 | Jev's accuracy and calibration compared with Claude plus a structured schema on *our* tasks (brand gate, anomaly triage, health scoring) | Phase 2 exit, per use case | 20+ labelled examples per use case, compared side by side |

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Premise mismatch**: people expect Jev to type *all* LLM I/O | High | Wrong enforcement, frustration | The routing table in `02` and a skill description that says "not for extraction or generation" |
| Early-access API churn (launched about 2026-09-15; plugin has about 4 commits) | High | Broken scripts | Keep all calls behind `jev_call.py`; pin the plugin version; wrapper has a REST fallback |
| Hook false positives block legitimate work | Medium | Friction, bypass habits | Warn → ask → deny rollout; `# jev: ignore` pragma; a per-signature false-positive gate under 5% |
| Bash writes bypass Write/Edit hooks [C4] | Medium | Enforcement gaps | Bash matcher plus a Stop diff backstop |
| Edit hooks see only fragments [C1] | High | Missed context | Stop backstop lints whole files |
| Type safety ≠ correctness [A3] | High | A valid but wrong decision | Always surface confidence; the threshold escalates to a human (exit 3) |
| Vendor claims not independently verified (REST endpoint, 255-option limit, "cannot hallucinate") | Medium | Wrong assumptions | Treat them as provisional until Q1 is resolved |
| Repo skills can grant themselves `allowed-tools` | Low | Scripts run without prompts | Review the skill in PRs; keep `allowed-tools` scoped to `${CLAUDE_SKILL_DIR}/scripts/*` |
| Data sent to a third-party API (client data, PII) | Medium | Privacy/compliance (e.g. health clients under AHPRA) | Classify data before sending; add a redaction step in `jev_call.py`; check TypeSafe's data-retention terms |
| Network and API key unavailable in cloud or sandboxed runs | Medium | Skill fails | Environment secrets plus a network allowlist; fail clearly with exit 4 |

## Decision log
| Date | Decision | By | Rationale |
|---|---|---|---|
| 2026-09-29 | Scope Jev to decision tasks only (Noul/Choice/Score), not generation or extraction | Research | Jev is a decision model [A1][A2] |
| 2026-09-29 | Skill name `jev-typed-decisions` | Research | Portable naming rules [B2] |
| 2026-09-29 | Enforcement rolls out warn → ask → deny, controlled by `JEV_ENFORCE` | Research | Hooks are deterministic but the detection is heuristic |
| | *(next decision)* | | |
