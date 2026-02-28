# Progressive Learning Engine

> **Purpose**: Instructions for Claude's adaptive learning system — detecting preferences, building patterns, maintaining confidence scores, and improving over time.
> **Last Updated**: 2026-02-28

## Core Principle

The learning engine transforms Claude from a stateless assistant into a personalized collaborator that remembers, adapts, and anticipates. All learning is:
- **Transparent**: User can review everything learned
- **Controllable**: User can edit, delete, or reset any learned preference
- **Local**: All state stored in `learning/` directory — never transmitted externally
- **Conservative**: Only act on high-confidence patterns; always ask when uncertain

---

## 1. Explicit Preference Capture

### Detection Signals
Watch for explicit preference statements:
- "I prefer..." / "I like..." / "I want..."
- "Always..." / "Never..." / "Don't..."
- "From now on..." / "Going forward..."
- "That's too {long/short/detailed/brief}..."
- "Can you make it more {format}..."
- Corrections: "No, I meant..." / "Actually, do it this way..."

### Recording Protocol
When an explicit preference is detected:

1. **Acknowledge**: "I'll remember that you prefer {preference}."
2. **Categorize**: Assign to a preference category:
   - `response_format`: How responses should be structured
   - `communication_style`: Tone, formality, verbosity
   - `tool_preferences`: Preferred connectors and tools
   - `department_defaults`: Per-department preferences
   - `notification_preferences`: When and how to be proactive
   - `scheduling_preferences`: Work patterns and timing
   - `content_preferences`: Types of content prioritized
3. **Record**: Write to `learning/preferences.json`:
   ```json
   {
     "id": "pref_XXXXXX",
     "category": "{category}",
     "preference": "{clear description}",
     "context": "{department or global}",
     "confidence": 1.0,
     "source": "explicit",
     "set_date": "YYYY-MM-DD"
   }
   ```
4. **Apply immediately**: Use the preference in the current session
5. **Update confidence**: Write to `learning/confidence-scores.json`

### Preference Override
When a new explicit preference contradicts an existing one:
1. Note the change: "Updating your preference from {old} to {new}."
2. Archive the old preference (set `status: "superseded"`)
3. Record the new preference with fresh confidence 1.0

---

## 2. Implicit Pattern Detection

### Observable Behaviors
Track these behavioral signals across sessions:

| Pattern Category | What to Watch For |
|---|---|
| `time_of_day` | Which departments/tasks at which times |
| `department_frequency` | How often each department is accessed |
| `context_switch_sequences` | Common department switch patterns |
| `response_format_feedback` | When user reformats or requests changes |
| `skill_usage` | Which skills are invoked most |
| `connector_usage` | Which connectors are preferred |
| `document_format` | Preferred document structures |
| `review_patterns` | How user reviews and approves content |

### Recording Protocol

After each session, extract observed patterns and record in `learning/observed-patterns.json`:

```json
{
  "id": "pattern_XXXXXX",
  "category": "{category}",
  "description": "{clear behavioral description}",
  "observations": [
    {
      "date": "YYYY-MM-DD",
      "context": "{what was happening}",
      "evidence": "{specific behavior observed}"
    }
  ],
  "observation_count": 1,
  "confidence": 0.30,
  "first_observed": "YYYY-MM-DD",
  "last_observed": "YYYY-MM-DD",
  "status": "active"
}
```

### Pattern Promotion
Patterns gain confidence through consistent observation:

| Observations | Confidence | Action |
|---|---|---|
| 1-2 | 0.30-0.45 | Track only, do not surface |
| 3-4 | 0.60-0.70 | Suggest to user: "I've noticed you tend to... Should I default to that?" |
| 5+ | 0.80 | Apply by default, mention briefly: "Using your usual format..." |
| User confirmed | 1.00 | Apply silently (becomes an explicit preference) |

---

## 3. Confidence Scoring System

### Score Calculation

Stored in `learning/confidence-scores.json`. Each preference/pattern has a confidence score:

**Boosting events:**
- New observation matching pattern: +0.15 (cap at 0.80 for behavioral)
- User explicitly confirms: set to 1.00
- User accepts suggestion based on pattern: +0.15

**Reducing events:**
- User contradicts pattern: -0.30
- User rejects suggestion: -0.30
- User ignores suggestion: -0.05
- Time decay: multiply by 0.95 every 30 days (for unconfirmed patterns only)

**Floor and ceiling:**
- Minimum confidence: 0.10 (below this, archive the pattern)
- Maximum from behavior only: 0.80 (only user confirmation reaches 1.00)
- Explicit preferences: always 1.00, never decays

### Confidence Thresholds for Action

| Level | Score | Behavior |
|---|---|---|
| **Certain** | >= 0.95 | Apply automatically, no mention needed |
| **High** | >= 0.80 | Apply automatically, briefly mention: "Using your preferred..." |
| **Moderate** | >= 0.60 | Suggest: "Based on your pattern, should I...?" |
| **Low** | >= 0.40 | Track internally, do not surface to user |
| **Speculative** | < 0.40 | Hypothesis only, may be archived |

---

## 4. Trend Analysis

### Weekly Analysis (via `scripts/workflows/weekly-review.py`)

Every week, analyze the last 30 days of patterns to detect:

1. **Department Focus Shifts**: Is the user spending more time in Strategy vs Operations?
2. **Project Priority Changes**: Are certain projects getting more attention?
3. **Tool Usage Evolution**: Are they adopting new connectors? Dropping old ones?
4. **Workflow Frequency Changes**: Are certain skills being used more/less?
5. **Communication Style Drift**: Are responses being reformatted more often?

Store trends in the weekly summary section of `context/session-patterns.json`.

### Trend-Based Suggestions

When a significant trend is detected (e.g., 50%+ increase in strategy department time over 2 weeks):
- Flag the trend as a proactive observation
- Suggest related workflow optimizations
- Adjust default skill and connector priorities

---

## 5. Feedback Loop

### Logging All Adaptations

Every time the learning system influences behavior, log in `learning/adaptation-log.json`:

```json
{
  "id": "adapt_XXXXXX",
  "date": "YYYY-MM-DDTHH:MM:SS",
  "type": "preference_applied|pattern_suggested|proactive_offered",
  "source_id": "{preference or pattern ID}",
  "description": "{what was done}",
  "outcome": "accepted|rejected|modified|ignored|pending",
  "user_feedback": "{any explicit feedback}",
  "confidence_before": 0.70,
  "confidence_after": 0.85
}
```

### Outcome Processing

After each adaptation outcome:
- **Accepted**: Boost source confidence by +0.15
- **Rejected**: Reduce source confidence by -0.30, log reason if given
- **Modified**: Create new preference capturing the modification
- **Ignored**: Slight reduction (-0.05), may indicate irrelevance rather than disagreement

### Self-Improvement Metrics

Track aggregate metrics:
- Overall suggestion acceptance rate
- Per-category acceptance rates
- False positive rate (suggestions rejected)
- Coverage (what % of interactions benefit from learned context)

---

## 6. Privacy and Control

### User Controls

Users can at any time:
- **View all learned preferences**: Read `learning/preferences.json`
- **View detected patterns**: Read `learning/observed-patterns.json`
- **View adaptation history**: Read `learning/adaptation-log.json`
- **Delete any preference**: Remove entry from preferences.json
- **Reset a pattern**: Delete entry from observed-patterns.json
- **Reset all learning**: Delete contents of all learning/ JSON files
- **Disable learning**: Set `proactive_level: "minimal"` in user-profile.json

### Data Locality

- All learning state is stored locally in `claude-plugin/learning/`
- No data is transmitted to external services
- Learning files can be `.gitignored` for private use or committed for team sharing
- State files are plain JSON — fully human-readable and editable

---

## 7. Anti-Hallucination in Learning

The learning system itself must follow anti-hallucination rules:

- **Never fabricate patterns**: Only record what is actually observed
- **Never inflate confidence**: Follow the scoring rules strictly
- **Mark all inferences**: Tag learned insights as `[ANALYSIS:INFERRED]`
- **Distinguish explicit from inferred**: Explicit preferences are `[CONFIRMED: user]`, patterns are `[ANALYSIS:INFERRED]`
- **Decay old patterns**: Don't let stale patterns influence behavior indefinitely
- **Acknowledge uncertainty**: When confidence is moderate, always frame as suggestion, not assertion
