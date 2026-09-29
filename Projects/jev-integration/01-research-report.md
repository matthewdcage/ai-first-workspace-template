# Research Report: Jev + Claude Code Skills & Hooks

*Deep-research run 2026-09-29: 5 search angles, 21 sources fetched, 40 claims extracted, 25 checked by 3-vote adversarial verification (22 confirmed, 3 refuted), 12 findings after merging duplicates.*

> **Premise correction.** The request described Jev as "typesafe AI", which suggests a type-safe LLM I/O library. It is actually **TypeSafe AI's classification and scoring model**. The plan below is built around that.

## A. What Jev is

### A1. Identity — *high confidence (3–0)*
Jev is TypeSafe AI's first public "System One" model: "Unstructured or structured state in → typed probabilistic decisions out." It does not generate text. It went into early access around **2026-09-15**, with docs at docs.typesafe.ai. You can use it from Simon Willison's **`llm-typesafe`** plugin for the `llm` CLI (Apache-2.0, very young at about 4 commits): model `typesafe/jev-latest`, alias `jev`.
Sources: [simonw/llm-typesafe](https://github.com/simonw/llm-typesafe) · [pjburnhill gist](https://gist.github.com/pjburnhill/adf8d28efcad9df037bfdece178ef965)

### A2. Three decision primitives — *high (3–0)*
| Type | Input | Output |
|---|---|---|
| **Noul** (default) | a yes/no question | probability of "yes", 0–1 (Bernoulli) |
| **Choice** | at least 2 described categories (gist says up to 255) | chosen option, per-option probabilities, confidence |
| **Score** | 2–10 ordered level descriptions, lowest to highest | score (can be fractional), legend, per-level probabilities, confidence |

In the plugin you set these with `-o answer_type ...` and `-o criteria ...`. The raw API is reported as `POST api.typesafe.ai/v1/systemone`, but that comes from secondary sources.
Sources: as A1.

### A3. What "type-safe" means here — *medium (3–0; vendor claim)*
Output is limited to the answer space you define, so Jev "cannot output… an unexpected value or malformed output outside the schema." The guarantee covers **schema validity only**. Its semantic judgements can still be wrong. The primary TypeSafe docs were unreachable from the research environment.
Source: [gist](https://gist.github.com/pjburnhill/adf8d28efcad9df037bfdece178ef965)

### A4. Strict structured input — *high (3–0)*
"Text is never automatically interpreted as JSON. With `input_format=json`, the entire prompt must parse as a JSON string, object, or array. Duplicate keys and non-finite numbers are rejected." Wrapper scripts must serialise their input canonically.
Source: [simonw/llm-typesafe](https://github.com/simonw/llm-typesafe)

## B. Claude Code Skills

### B1. Structure & progressive disclosure — *high (3–0)*
A skill is a `SKILL.md` file (YAML frontmatter plus Markdown), loaded in three levels:
1. **name + description**, about 100 tokens, always in context
2. **SKILL.md body**, loaded when the skill triggers (guidance: under 5k tokens, under 500 lines)
3. **bundled references and scripts**, no cost until used. Keep references one level deep.
Sources: [Claude Code skills docs](https://code.claude.com/docs/en/skills) · [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) · [Best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

### B2. Naming & triggering — *high (3–0)*
For portability, use lowercase letters, digits and hyphens, at most 64 characters, and do not use "anthropic" or "claude" in the name. Use `jev-typed-decisions`, not `claude-jev`. The description drives automatic triggering: the Agent Skills spec caps it at 1,024 characters, and Claude Code truncates `description` plus `when_to_use` at 1,536 characters by default. Put the key use case first. Claude Code itself is more lenient (name defaults to the directory name).
Sources: [Best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) · [skills docs](https://code.claude.com/docs/en/skills)

### B3. Bundled scripts — *high (3–0)*
Put deterministic work (calling Jev, validating criteria, linting) in scripts. Only the script's output enters context, not its code. Reference scripts as `${CLAUDE_SKILL_DIR}/scripts/...` and pre-approve them with a matching `allowed-tools` Bash rule (the grant lasts for the turn that invoked the skill; `deny`/`ask` rules still win). Plugins use `${CLAUDE_PLUGIN_ROOT}`. SKILL.md should tell Claude to **run** the scripts, not read them.
Sources: as B1.

### B4. Skills and CLAUDE.md advise; hooks enforce — *high (3–0)*
CLAUDE.md is "context, not enforced configuration." For behaviour that must always happen, Anthropic recommends hooks and `permissions.deny`. Skills can declare `hooks` in frontmatter. These register when the skill is invoked and stay active for the rest of the session (unless `once` is set).
Sources: [skills docs](https://code.claude.com/docs/en/skills) · [Steering Claude Code blog](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more)

## C. Claude Code Hooks

### C1. Blocking semantics — *high (3–0)*
- A **PreToolUse** hook on `Edit|Write` can inspect `tool_input.content` / `new_string` and return `hookSpecificOutput.permissionDecision` = `allow|deny|ask|defer` with a `permissionDecisionReason`. Claude sees the reason, which is how the hook steers.
- **Exit 2** blocks unconditionally, and a JSON `allow` cannot override it. **Exit 0** is required for JSON output to be read. **Exit 1 does not block.**
- An Edit hook sees only the fragment being changed, not the whole file.
Sources: [hooks docs](https://code.claude.com/docs/en/hooks) · [Steering blog](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more)

### C2. Soft steering and backstops — *high (3–0)*
`additionalContext` injects non-blocking guidance as a system reminder, which suits `UserPromptSubmit` and `SessionStart` nudges. A PostToolUse `decision: block` is feedback **after** the tool has run, not prevention. A **Stop** hook can make Claude keep working, for example until a lint check passes.
Source: [hooks docs](https://code.claude.com/docs/en/hooks)

### C3. Where hooks live — *high (3–0)*
`~/.claude/settings.json` (user), `.claude/settings.json` (project, committed), `.claude/settings.local.json` (gitignored), managed policy, skill or subagent frontmatter, and a plugin's `hooks/hooks.json`, which merges with the others. **A plugin that bundles the skill and hooks is the most portable package.** Cloud sessions do not read the local `~/.claude/settings.json`.
Source: [hooks docs](https://code.claude.com/docs/en/hooks)

### C4. The Bash bypass — *medium (3–0; forum source)*
A hook that matches only `Write|Edit` misses files written through Bash (heredocs, `>` redirects). Match `Bash` as well (inspect `tool_input.command`), and add a scan of changed files at PostToolUse/Stop as the robust backstop.
Source: [anthropics/claude-code#45427](https://github.com/anthropics/claude-code/issues/45427) (RFC, closed not-planned)

## D. Refuted during verification (do not rely on these)
| Claim | Vote |
|---|---|
| SKILL.md strictly *requires* name/description with those limits (true for the API spec, not for Claude Code) | 1–2 |
| The gist explicitly says Jev is "not for research, long reasoning, prose…" (not supported as sourced; consistent with A1 but unconfirmed) | 0–3 |
| Subagent tool calls bypass parent PreToolUse hooks (issue #43772) | 0–3, but still test it (see risks) |

## E. Source quality
Primary: code.claude.com skills/hooks docs, platform.claude.com Agent Skills docs, claude.com steering blog, simonw/llm-typesafe. Secondary: pjburnhill gist, claude-code issue #45427. The typesafe.ai and docs.typesafe.ai pages, and several third-party blogs, could not be fetched and are **not** cited as evidence.
