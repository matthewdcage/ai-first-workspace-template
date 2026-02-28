# Context Engine — Multi-Layer Context Management

> **Purpose**: Instructions for assembling, merging, and maintaining multi-layer context across sessions, departments, and platforms.
> **Last Updated**: 2026-02-28

## Overview

The context engine manages 5 layers of context that combine to create a personalized, department-aware, historically-informed interaction experience. Each layer has different persistence, update frequency, and priority.

---

## Layer 1: Identity Context (Highest Priority)

**Source**: `config/user-profile.json`
**Persistence**: Permanent (manually edited by user)
**Update frequency**: Rarely — only when user role or preferences change

### What it provides:
- User name, role, title, organization
- Communication style preferences (concise/detailed/balanced)
- Platform-specific formatting overrides (Desktop vs iOS)
- Work patterns (peak hours, meeting days, focus time preferences)
- Expertise levels and domain knowledge
- Department access permissions
- Anti-hallucination settings

### Loading instructions:
1. Read `config/user-profile.json` at session start
2. Check for `[PLACEHOLDER: user]` fields — prompt user to fill these if critical fields are empty
3. Apply `communication.platform_overrides` based on detected platform
4. Store loaded profile in session memory for duration of conversation

---

## Layer 2: Session Context (High Priority)

**Source**: Runtime (ephemeral — not persisted)
**Persistence**: Single session only
**Update frequency**: Continuous during conversation

### What it tracks:
- Current conversation topic and intent
- Active task chain (nested tasks and subtasks)
- Files referenced or modified this session
- Decisions made this session (with rationale)
- Context switches performed this session
- Skills invoked this session
- Connectors used this session

### Management rules:
- Initialize empty at session start
- Update after each significant interaction
- Use for deduplication (don't re-suggest dismissed items)
- Use for continuity (remember earlier decisions in multi-step tasks)
- At session end: extract significant patterns → feed to Learning system

---

## Layer 3: Department Context (High Priority)

**Source**: `Docs/{Department}/.cursorrules` + active department skills
**Persistence**: Semi-permanent (loaded/unloaded on context switch)
**Update frequency**: On context switch

### What it provides:
- Department-specific behavioral rules (from `.cursorrules`)
- Relevant file paths and document structures
- Department vocabulary and terminology
- Competitive positioning context (for Strategy)
- Evaluation frameworks (for Hiring)
- Client context (for Sales & Marketing)
- Financial models and metrics (for Finance)

### Context switch protocol:
1. User triggers switch: "Use {department} context"
2. Existing system: Load `Docs/{Department}/.cursorrules`
3. Plugin: Update `workspace-context.json` → set `active_department`
4. Plugin: Load `skills/department/{department}-skills.md`
5. Plugin: Activate department-default connectors from `config/defaults.json`
6. Plugin: Check department-specific proactive triggers
7. Plugin: Record context switch in session context and `session-patterns.json`

### Department-skill mappings:
| Department | Skills File | Default Connectors |
|---|---|---|
| strategy | `strategy-skills.md` | web_search, filesystem, google_sheets |
| product | `product-skills.md` | filesystem, github, notion |
| sales_marketing | `sales-marketing-skills.md` | filesystem, notion, slack, calendar |
| operations | `operations-skills.md` | filesystem, google_sheets, slack |
| hiring | `operations-skills.md` (hiring section) | filesystem, notion |
| finance | `finance-skills.md` | filesystem, google_sheets, code_execution |

---

## Layer 4: Workspace Context (Medium Priority)

**Source**: `context/workspace-context.json`
**Persistence**: Persistent across sessions (auto-managed)
**Update frequency**: At session start/end and on significant events

### What it tracks:
- Active department and project
- Recently accessed files (last 20)
- Department activity recency (which departments were last accessed)
- Pending items across departments (stale documents, broken refs)
- Connector sync status
- Cross-reference integrity (CANONICAL/REF tag health)

### Staleness detection:
- If `last_sync` > 24 hours: Suggest running workspace sync
- If `active_project.last_activity` > 7 days: Note project may be stale
- If any department `last_accessed` > 30 days: Deprioritize in suggestions

---

## Layer 5: Historical Context (Lowest Priority)

**Source**: `learning/preferences.json`, `learning/observed-patterns.json`, `learning/confidence-scores.json`
**Persistence**: Persistent, accumulates over time
**Update frequency**: End of each session + weekly trend analysis

### What it provides:
- Explicit user preferences (highest confidence)
- Behavioral patterns (variable confidence, decaying)
- Trend analysis (shifting priorities over 30-day windows)
- Adaptation history (what worked, what was rejected)

### Application rules:
- **Certain** (>= 0.95): Apply without asking — these are confirmed preferences
- **High** (>= 0.80): Apply and briefly mention — "Using your preferred format..."
- **Moderate** (>= 0.60): Suggest and ask — "Based on your usual pattern, should I...?"
- **Low/Speculative** (< 0.60): Do not surface — track internally only
- **Never override** explicit session context with historical patterns

---

## Context Merging Rules

### Priority Ordering
```
Identity > Session > Department > Workspace > Historical
```

### Conflict Resolution

When layers conflict:

| Scenario | Resolution |
|---|---|
| User profile says "concise" but department rules say "detailed" | Use department rules (closer to task) |
| Session decision contradicts learned pattern | Session wins (explicit > inferred) |
| Historical pattern conflicts with new explicit preference | New preference wins, update historical |
| Two connectors could serve same need | Prefer the one with higher usage_frequency in connectors.json |
| Platform override conflicts with department format | Platform override wins for formatting only |

### Information Completeness

For each response, ensure you have:
- [ ] User identity context loaded
- [ ] Active department context loaded (if department is set)
- [ ] Relevant learned preferences checked
- [ ] Required connector availability verified
- [ ] Anti-hallucination rules active

If any critical context is missing, state what's missing and ask user before proceeding.

---

## Cross-Session Pattern Extraction

At session end, extract and record:

1. **Department time distribution**: How long was each department context active?
2. **Skill usage**: Which skills were invoked? How often?
3. **Connector usage**: Which connectors were used? For what?
4. **Decision patterns**: What kind of decisions were made? What was the outcome?
5. **Format preferences**: Did user modify or override any formatting?
6. **Suggestion outcomes**: Were proactive suggestions accepted, rejected, or ignored?

Store extracted patterns in `context/session-patterns.json` for the Learning system to process.

---

## Platform Detection

Determine platform context to adapt response formatting:

- **Claude Desktop**: Full markdown, cross-references, source tags, up to 3 proactive suggestions
- **Claude iOS**: Bullet points, no cross-references, brief format, max 1 proactive suggestion, offer tap actions
- **Claude Web**: Similar to Desktop but slightly more concise
- **Unknown**: Default to Desktop format

Apply platform overrides from `config/user-profile.json#communication.platform_overrides`.
