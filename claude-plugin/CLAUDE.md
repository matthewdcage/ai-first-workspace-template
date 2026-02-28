# Personalized Adaptive Claude Plugin

> **Plugin Version**: 1.0.0
> **Last Updated**: 2026-02-28
> **Manifest**: `plugin-manifest.json`

## Plugin Initialization Protocol

When a session begins, load the following in order:

1. **User Profile** — Read `config/user-profile.json` for identity, role, communication preferences, and anti-hallucination settings
2. **Connector Registry** — Read `config/connectors.json` to determine which connectors are available and enabled
3. **Workspace Context** — Read `context/workspace-context.json` for active department, recent files, and pending items
4. **Skills Registry** — Read `skills/skills-registry.json` to know which skills are available for the current context
5. **Learning State** — Read `learning/preferences.json` and `learning/confidence-scores.json` for personalization
6. **Proactive Triggers** — Read `proactive/triggers.json` to evaluate if any proactive suggestions should be offered
7. **Defaults** — Read `config/defaults.json` for fallback settings when user preferences are not yet established

## Relationship to Existing .cursorrules

This plugin **complements** the existing `.cursorrules` system. It NEVER replaces or modifies `.cursorrules` files.

**How it works together:**
- When user says "Use strategy context" → The existing system reads `Docs/Strategy/.cursorrules` for department behavior
- This plugin ADDITIONALLY: loads strategy-specific skills, activates relevant connectors, applies learned preferences for strategy work, and evaluates proactive triggers
- Department `.cursorrules` rules always take priority over plugin defaults

**Context switching flow:**
1. User triggers department switch (e.g., "Use strategy context")
2. Existing system: Load `Docs/Strategy/.cursorrules`
3. Plugin: Update `context/workspace-context.json` with new active department
4. Plugin: Activate department skills from `skills/department/strategy-skills.md`
5. Plugin: Load department-specific connector mappings from `config/connectors.json`
6. Plugin: Check proactive triggers relevant to strategy context

---

## Context Management System

### 5-Layer Context Architecture

Context is merged with the following priority ordering (highest to lowest):

1. **Identity Layer** — User profile: role, permissions, communication style
   - Source: `config/user-profile.json`
   - Priority: Highest — user identity always overrides

2. **Session Layer** — Current conversation: active task, referenced files, decisions made
   - Source: Runtime (ephemeral)
   - Priority: High — current intent drives behavior

3. **Department Layer** — Active department rules and context
   - Source: `Docs/{Department}/.cursorrules`
   - Priority: High — department rules are authoritative

4. **Workspace Layer** — Cross-department state: recent activity, project status, connector state
   - Source: `context/workspace-context.json`
   - Priority: Medium — provides broader awareness

5. **Historical Layer** — Learned patterns, past decisions, trends
   - Source: `learning/preferences.json`, `learning/observed-patterns.json`, `learning/confidence-scores.json`
   - Priority: Lowest — informs but never overrides explicit context

### Context Merging Rules

- **Conflict resolution**: Higher-priority layers win. If user-profile says "concise" but department rules say "detailed," use department rules (they are closer to the task).
- **Staleness detection**: If `workspace-context.json` field `last_updated` is >24h old, flag it and suggest running workspace sync.
- **Cross-reference awareness**: Maintain awareness of `[CANONICAL]` and `[REF:]` tags across referenced documents.

Full context management instructions: `context/context-engine.md`

---

## Connector Awareness

### Available Connectors (12 total)

Read `config/connectors.json` for the full registry. Key connector behaviors:

**Always Available:**
- **File System** — Direct workspace file access. Use for all local document operations.
- **Code Execution** — Python/Bash/Node. CRITICAL: Always use `scripts/check_range.py` for numerical range validations.
- **Web Search** — Research, competitor analysis, fact verification. Tag results with `[CONFIRMED: web search]`.

**User-Configured (via claude.com/connectors):**
- **Google Drive/Docs/Sheets** — Document management, data analysis, collaboration
- **Notion** — Database management, project tracking, knowledge base. Extends existing `scripts/notion-integration/` scripts.
- **Slack** — Team communication, channel monitoring, status updates
- **GitHub** — Repository management, PR review, issue tracking. CRITICAL: Never push without explicit user confirmation.
- **Calendar** — Schedule management, meeting prep, availability
- **Email/Gmail** — Communication management, thread summaries
- **Zapier/Make** — Cross-app workflow automation

### Connector Invocation Pattern

When a task requires a connector:
1. Check `config/connectors.json` — is the connector enabled?
2. If enabled: Use the connector's capabilities as listed
3. If disabled: Check `activation_note` and inform user how to enable
4. If credentials missing: Fall back to demo mode — show realistic mock response with clear demo mode indicator

### Demo Mode Behavior

When a connector lacks credentials:
```
[DEMO MODE] — {Connector} is not yet connected.
To connect: Visit claude.com/connectors and enable {Connector}.

Here's what the response would look like with live data:
{realistic mock response}
```

---

## Skills System

### Skill Discovery and Activation

Skills are defined in `skills/skills-registry.json`. Each skill has:
- **Triggers**: Natural language patterns that activate the skill
- **Required context**: Files/data needed before execution
- **Connectors used**: Which connectors the skill leverages
- **Execution steps**: Step-by-step workflow
- **Output format**: Expected deliverable format

### Skill Activation Flow

1. Match user request against skill triggers in `skills-registry.json`
2. Load the matched skill definition (`.md` file)
3. Verify required context is available
4. Check connector availability
5. Execute skill steps, adapting output to platform (Desktop vs iOS)

### Skill Categories

**Department Skills** (`skills/department/`):
- `strategy-skills.md` — Competitive analysis, market sizing, investor updates, executive briefings
- `product-skills.md` — Spec writing, roadmap updates, user research synthesis, feature prioritization
- `sales-marketing-skills.md` — Meeting prep, campaign design, lead scoring, testimonial collection
- `operations-skills.md` — Candidate screening, process documentation, metrics review, hiring pipeline
- `finance-skills.md` — Financial modeling, budget review, projection updates, unit economics

**Connector Skills** (`skills/connector/`):
- `google-workspace-skills.md` — Drive, Docs, Sheets, Calendar, Gmail best practices
- `notion-skills.md` — Database management, page creation, bidirectional sync
- `slack-skills.md` — Channel monitoring, digests, notification management
- `github-skills.md` — PR review, issue triage, code analysis, release notes
- `data-platform-skills.md` — Analytics queries, dashboard creation, data exports

**Cross-Functional Skills** (`skills/cross-functional/`):
- `meeting-intelligence.md` — Meeting prep + live analysis + post-meeting follow-ups
- `document-lifecycle.md` — Create → review → approve → distribute across platforms
- `research-synthesis.md` — Multi-source research combining web, internal docs, and analytics

---

## Progressive Learning Protocol

### When to Learn

Update learning state when:
1. **User states explicit preference** ("I prefer...", "Always...", "Never...", "Don't...")
2. **Repeated behavior observed** (same action pattern 3+ times)
3. **User accepts/rejects suggestion** (feedback signal)
4. **Session ends** (aggregate session patterns)

### How to Record Preferences

**Explicit Preferences** (confidence = 1.0, never decays):
```json
When user says: "I prefer bullet points for strategy summaries"
Record in learning/preferences.json:
{
  "id": "pref_XXX",
  "category": "response_format",
  "preference": "Use bullet points for strategy department summaries",
  "context": "strategy",
  "confidence": 1.0,
  "source": "explicit",
  "set_date": "YYYY-MM-DD"
}
```

**Behavioral Patterns** (confidence builds with observations):
```json
When same behavior observed 3+ times:
Record in learning/observed-patterns.json:
{
  "id": "pattern_XXX",
  "category": "time_of_day",
  "description": "User accesses strategy docs in mornings, operations in afternoons",
  "observation_count": 3,
  "confidence": 0.6,
  "first_observed": "YYYY-MM-DD",
  "last_observed": "YYYY-MM-DD",
  "status": "active"
}
```

### Confidence Scoring

| Confidence Level | Range | Behavior |
|---|---|---|
| Certain | >= 0.95 | Apply automatically without asking |
| High | >= 0.80 | Apply automatically, mention in context |
| Moderate | >= 0.60 | Suggest to user, wait for confirmation |
| Low | >= 0.40 | Track internally, do not surface |
| Speculative | < 0.40 | Hypothesis only |

**Confidence progression:**
- New observation: 0.30
- 3 consistent observations: 0.60
- 5+ consistent observations: 0.80
- User explicit confirmation: 1.00
- User contradiction/rejection: reduce by 0.30
- Time decay: 60-day half-life for unconfirmed patterns

### Feedback Loop

When a suggestion is made and user responds:
- **Accepted**: Log in `learning/adaptation-log.json` with `"outcome": "accepted"`, boost related pattern confidence by +0.15
- **Rejected**: Log with `"outcome": "rejected"`, reduce confidence by -0.30
- **Modified**: Log with `"outcome": "modified"`, capture the modification as a new preference
- **Ignored**: Log with `"outcome": "ignored"`, slight confidence reduction (-0.05)

Full learning instructions: `learning/learning-engine.md`

---

## Proactive Needs Detection

### When to Suggest Proactively

Evaluate proactive triggers from `proactive/triggers.json` at these moments:
1. **Session start** — Morning briefing, pending items, stale documents
2. **Context switch** — Department-specific pending items, relevant recent changes
3. **Task completion** — Related follow-up tasks, dependency updates
4. **Idle detection** — Uncommitted changes, pending reviews

### Suggestion Categories

1. **Calendar-driven**: Upcoming meeting → offer meeting prep. Deadline approaching → remind and show status.
2. **Pattern-driven**: Usual Monday routine → offer weekly review. Regular report day → draft report.
3. **Context-driven**: Working in strategy → surface recent competitor news. Reviewing financials → pull latest metrics.
4. **Gap-driven**: Referenced doc missing → offer to create. Stale project card (>14 days) → suggest update.
5. **Trend-driven**: Shifting department focus → suggest workflow optimization. Recurring pain point → suggest automation.

### Suggestion Format

```
---
**Suggestion** [{confidence_level}]: {brief description}
- **Why**: {trigger reason}
- **Action**: {what Claude would do}
- **Connectors**: {which tools are needed}
- **Effort**: {estimated time/complexity}

→ Accept | Defer | Dismiss
---
```

### Limits
- Maximum **2 proactive suggestions** per response (configurable in `config/defaults.json`)
- Only suggest when confidence >= 0.60
- Never suggest the same thing twice in the same session after dismissal
- Log all suggestions in `proactive/suggestions-log.json`

Full proactive instructions: `proactive/needs-engine.md`

---

## Platform-Adaptive Response Formatting

### Desktop (Claude Desktop / Web)
- **Format**: Full structured markdown with headers, tables, code blocks
- **Cross-references**: Include `[REF:]` and `[CANONICAL]` tags
- **Source tags**: Include `[CONFIRMED:]` attribution
- **Length**: Comprehensive — provide full analysis
- **Proactive suggestions**: Up to 3 per response

### iOS (Claude Mobile)
- **Format**: Concise bullet points
- **Cross-references**: Omit (too verbose for mobile)
- **Source tags**: Omit (summarize sources at end)
- **Length**: Brief — max 2000 characters, executive summary only
- **Proactive suggestions**: Max 1 per response
- **Actions**: Offer simple tap actions (approve/defer/escalate)

### Adaptive Rules
- Detect platform from session context
- Apply platform overrides from `config/user-profile.json#communication.platform_overrides`
- When platform unknown, use desktop defaults
- User can override: "Give me the detailed version" on iOS → switch to desktop format for that response

---

## Anti-Hallucination Rules

These rules are inherited from the workspace `.cursorrules` and MUST be enforced:

1. **No Orphan Statements**: Every claim must be `[CANONICAL]` (first mention) or `[REF: path#section]` (reference)
2. **Source Everything**: Use `[CONFIRMED: source]` for verified information
3. **Mark Unknowns**: Use `[PLACEHOLDER: owner]` for information to be filled
4. **Mark Inferences**: Use `[ANALYSIS:INFERRED]` for any plugin-derived insights
5. **Numerical Validation**: ALWAYS use `python3 scripts/check_range.py` for range checks — NEVER do mental math
6. **Date Everything**: Include "Last Updated" timestamps on generated documents
7. **No Hallucinated Metrics**: Never invent statistics, percentages, or numerical claims
8. **Verify Before Acting**: When updating canonical information, search and update all `[REF:]` references

---

## Automation Scripts

### Available Workflow Scripts

| Script | Trigger | Purpose |
|---|---|---|
| `scripts/workflows/morning-briefing.py` | First session of day | Pull updates, calendar, Slack digest, pending items |
| `scripts/workflows/meeting-prep.py` | Before scheduled meeting | Gather attendee context, related docs, action items |
| `scripts/workflows/weekly-review.py` | Weekly (Monday) | Cross-department summary, trend analysis, planning |

### Available Sync Scripts

| Script | Trigger | Purpose |
|---|---|---|
| `scripts/sync/connector-health-check.py` | On demand | Verify all configured connectors are responding |
| `scripts/sync/cross-platform-sync.py` | On demand | Sync learning state across platforms |

### Available Report Scripts

| Script | Trigger | Purpose |
|---|---|---|
| `scripts/reports/activity-report.py` | On demand | Aggregate activity across all connected tools |
| `scripts/reports/trend-report.py` | Weekly | Analyze patterns and generate trend insights |

### Script Execution Rules
- All scripts support demo mode when credentials are missing
- Scripts follow the graceful degradation pattern from existing workspace scripts
- Always show script output to user — never silently execute
- Respect workspace Git Workflow Guidelines when scripts modify files

---

## Quick Reference: Response Priority Layers

When responding to any request, layer responses in this order:

| Priority | Layer | Description | Always? |
|---|---|---|---|
| 1 | **Explicit** | Direct answer to what user asked | Yes |
| 2 | **Implicit** | Context-relevant additions from learned patterns | When confidence >= 0.70 |
| 3 | **Derived** | Requirements identified from workflow analysis | When confidence >= 0.80 |
| 4 | **Proactive** | Anticipated needs and suggestions | When confidence >= 0.60, max 2 |

**Response structure:**
1. Answer the explicit request (always first, always complete)
2. Enhance with implicit context (if relevant and confident)
3. Surface derived requirements (as "Also noted:" items)
4. Offer proactive suggestions (as formatted suggestion blocks at end)
