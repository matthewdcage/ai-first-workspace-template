# Jev (TypeSafe AI) Integration — Project Index

**Status:** Planning complete, not yet implemented · **Researched:** 2026-09-29 · **Owner:** @matthewdcage

This folder is the durable home for integrating **Jev** (TypeSafe AI's typed decision model) into Claude Code skills, with hooks enforcing its use where it fits. Every file is plain Markdown so humans can read it and agents can find it by path.

| File | Purpose | Read when |
|---|---|---|
| [`01-research-report.md`](01-research-report.md) | Verified findings with sources: what Jev is, how skills and hooks work | You need the facts or citations |
| [`02-integration-plan.md`](02-integration-plan.md) | Phased plan: skill → use-case integrations → enforcement hooks | Deciding or doing the work |
| [`03-skill-spec.md`](03-skill-spec.md) | Concrete `jev-typed-decisions` skill layout, SKILL.md draft, scripts | Building the skill |
| [`04-hooks-spec.md`](04-hooks-spec.md) | Hook configurations, detection rules, rollout modes (warn → ask → deny) | Building the enforcement layer |
| [`05-open-questions-and-risks.md`](05-open-questions-and-risks.md) | Unknowns, risks, decisions still needed | Before moving any phase forward |

## One-paragraph summary

Jev is **not** a type-safe codegen or schema library. It is a *decision model*: you give it input plus a typed answer space, and it returns one of three forms: **Noul** (probability of yes/no), **Choice** (one of N categories, with probabilities and confidence) or **Score** (a position on an ordered rubric of 2–10 levels). It never returns anything outside the schema you defined, though its judgement can still be wrong. So the integration targets **LLM-as-decision** work: gates, routing, classification, rubric scoring and LLM-as-judge. It does **not** target extraction, summarisation or text generation. Enforcement works in layers. A skill supplies the know-how, a CLAUDE.md rule supplies the intent (advisory only), and hooks supply the guarantee, rolled out warn-first.

## Agent instructions

- Before creating or changing anything Jev-related, read `02-integration-plan.md` and follow the phase order.
- Do not switch hooks to blocking (`deny` / exit 2) before Phase 3 exit criteria are met (see `04-hooks-spec.md`).
- Record decisions in the "Decision log" section of `05-open-questions-and-risks.md`.
