# Proactive Needs Detection Engine

> **Purpose**: Instructions for anticipating user needs before they are expressed, based on calendar events, behavioral patterns, workspace context, gap detection, and trend analysis.
> **Last Updated**: 2026-02-28

## Core Principle

Proactive suggestions should feel helpful, not intrusive. The engine operates on the principle that the best assistant anticipates needs but respects autonomy. Every suggestion is:
- **Transparent**: Always explains WHY it's being suggested
- **Dismissable**: User can always say no without consequences
- **Confidence-gated**: Only suggests when confidence meets threshold
- **Rate-limited**: Maximum 2 suggestions per response (configurable)
- **Session-aware**: Never repeats dismissed suggestions in the same session

---

## Detection Categories

### 1. Calendar-Driven Needs

**Trigger conditions**:
- Upcoming meeting within 30 minutes → Meeting prep
- Meeting in next 24 hours with external attendees → Client prep
- Deadline within 48 hours → Status check + reminder
- Recurring meeting due → Prepare recurring agenda/materials
- No meetings scheduled (focus block) → Deep work suggestions

**Actions**:
| Condition | Suggestion | Skill Invoked |
|---|---|---|
| Meeting in 30min | "You have a meeting with {attendee} in {time}. Want me to prepare a briefing?" | meeting-intelligence (prep phase) |
| Client meeting tomorrow | "Tomorrow's meeting with {client} — want me to pull their latest context?" | sales-marketing (meeting prep) |
| Deadline in 48h | "{deliverable} is due in {time}. Current status?" | document-lifecycle (review phase) |
| Focus block | "You have a clear block. Good time for {most_pending_task}?" | Context-dependent |

### 2. Pattern-Driven Needs

**Trigger conditions** (based on `learning/observed-patterns.json`):
- Monday morning → Weekly review (if pattern confidence >= 0.60)
- Regular report day → Draft preparation
- Usual context switch time → Pre-load next context
- End of day → Suggest commit and review
- End of week → Weekly summary

**Actions**:
| Pattern | Suggestion | Confidence Required |
|---|---|---|
| Monday morning routine | "It's Monday morning. Run the weekly cross-department review?" | 0.60 |
| Regular report day | "It's {day} — time for the {report_type}?" | 0.70 |
| Usual department switch | "Based on your usual flow, ready to switch to {department}?" | 0.70 |
| End-of-day pattern | "You've modified {n} files today. Review and commit?" | 0.60 |

### 3. Context-Driven Needs

**Trigger conditions** (based on current session context):
- Working in Strategy → Surface recent competitor news
- Reviewing financials → Pull latest metrics from sheets
- Editing product docs → Check for related GitHub issues
- In hiring context → Surface candidates needing evaluation
- In sales context → Check for upcoming client meetings

**Actions**:
| Context | Suggestion | Connectors |
|---|---|---|
| Strategy department active | "Recent news about {competitor}: {headline}. Want analysis?" | web_search |
| Finance department active | "Latest metrics from {sheet}: {summary}. Want full review?" | google_sheets |
| Product department active | "{n} open GitHub issues related to this feature area" | github |
| Hiring context active | "{n} candidates awaiting evaluation for {position}" | filesystem, notion |
| Sales context active | "Next client meeting: {client} on {date}. Prep now?" | calendar, filesystem |

### 4. Gap-Driven Needs

**Trigger conditions** (from workspace state analysis):
- Document references a file that doesn't exist → Offer to create
- `[PLACEHOLDER: owner]` tag older than 14 days → Remind to fill
- `[REF:]` tag points to moved/deleted file → Alert broken reference
- Project status card not updated in >14 days → Suggest update
- Department cursorrules referenced but file is empty/missing → Alert

**Actions**:
| Gap Detected | Suggestion |
|---|---|
| Missing referenced file | "Document references {path} which doesn't exist. Create it?" |
| Stale placeholder | "{n} placeholders in {file} haven't been filled (oldest: {days} days). Review?" |
| Broken cross-reference | "Found {n} broken [REF:] tags. Want to see the list?" |
| Stale project card | "Project {name} status hasn't been updated since {date}. Update?" |

### 5. Trend-Driven Needs

**Trigger conditions** (from weekly trend analysis):
- Department focus shift >30% over 2 weeks → Note the shift
- Skill usage surge → Suggest workflow optimization
- Connector adoption change → Suggest integration improvement
- Recurring manual task → Suggest automation

**Actions**:
| Trend | Suggestion |
|---|---|
| Department focus shift | "You've been spending {x}% more time in {dept} lately. Want to set up dept-specific shortcuts?" |
| Skill usage surge | "You've used {skill} {n} times this week. Want me to create a template for it?" |
| Recurring manual task | "I've noticed you manually {task} frequently. Want me to create an automation script?" |

---

## Suggestion Formatting

Each proactive suggestion follows this format:

```
---
**Suggestion** [{confidence_level}]: {brief one-line description}
- **Why**: {trigger reason — what was detected}
- **Action**: {what Claude would do if accepted}
- **Connectors**: {which tools are needed}
- **Effort**: {quick (< 2min) | moderate (2-10min) | significant (10+ min)}

→ Accept | Defer | Dismiss
---
```

**iOS format** (condensed):
```
Suggestion: {one-line description}
→ Accept | Later | No
```

---

## Rate Limiting and Prioritization

### Rate Limits
- **Per response**: Maximum 2 suggestions (configurable in `config/defaults.json`)
- **Per session**: Maximum 10 suggestions total
- **After dismissal**: Never repeat the same suggestion type in the same session
- **Cool-down**: After 2 consecutive dismissals, reduce proactive level for rest of session

### Priority Ordering (when multiple suggestions qualify)

1. **Calendar-driven** (time-sensitive — meetings approaching)
2. **Gap-driven** (integrity issues — broken references, missing files)
3. **Context-driven** (relevant to current work)
4. **Pattern-driven** (based on learned behavior)
5. **Trend-driven** (long-term optimization)

If more suggestions qualify than the rate limit allows, show highest priority ones and note: "I have {n} more suggestions when you're ready."

---

## Confidence Requirements

| Detection Category | Minimum Confidence |
|---|---|
| Calendar-driven | 0.50 (based on calendar data, not patterns) |
| Pattern-driven | 0.60 (need established pattern) |
| Context-driven | 0.50 (based on active context) |
| Gap-driven | 0.90 (high confidence — factual detection) |
| Trend-driven | 0.70 (need clear trend) |

---

## Logging

Every suggestion generated (whether shown or not) is logged in `proactive/suggestions-log.json`:

```json
{
  "id": "suggest_XXXXXX",
  "date": "ISO8601",
  "category": "calendar|pattern|context|gap|trend",
  "trigger": "description of what triggered this",
  "suggestion": "the suggestion text",
  "confidence": 0.75,
  "shown_to_user": true,
  "outcome": "accepted|rejected|deferred|ignored|not_shown",
  "reason_not_shown": "rate_limited|below_confidence|already_dismissed"
}
```

This log feeds back into the learning engine to improve suggestion quality over time.

---

## User Control

Users can control proactive behavior through `config/user-profile.json`:

| Setting | Options | Effect |
|---|---|---|
| `proactive_level` | `"minimal"` | Only gap-driven suggestions (integrity issues) |
| `proactive_level` | `"moderate"` | Calendar + gap + high-confidence patterns (default) |
| `proactive_level` | `"high"` | All categories, max suggestions |
| `proactive_level` | `"off"` | No proactive suggestions at all |
