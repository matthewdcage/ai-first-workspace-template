# Slack Connector Skills

> **Connector**: Slack
> **Platform**: Desktop, iOS, Web
> **Setup**: Connect via claude.com/connectors

## Skills

### 1. Channel Summary
**Triggers**: "slack summary", "what happened in slack", "channel digest", "catch up on slack"

**Process**:
1. Identify target channel(s) from `connectors.json` workspace_mappings or user request
2. Fetch recent messages (configurable time window, default: last 24h)
3. Categorize: Decisions, Action Items, Questions, FYIs, Discussions
4. Highlight messages that mention the user or their projects
5. Present: summary on Desktop, condensed bullet list on iOS

**Output**: Channel digest organized by category.

### 2. Post Update
**Triggers**: "post to slack", "notify team", "slack announcement", "share in channel"

**Process**:
1. Determine target channel and message content
2. Format message using Slack mrkdwn (bold, lists, code blocks)
3. Preview message to user before sending
4. **NEVER send without explicit user confirmation**
5. Post and confirm delivery

### 3. Thread Summary
**Triggers**: "summarize thread", "what's the thread about", "thread recap"

**Process**:
1. Identify the thread (from link or search)
2. Read all replies in thread
3. Extract: Main Topic, Key Points, Decisions, Open Questions, Action Items
4. Present structured summary

### 4. Notification Management
**Triggers**: "slack notifications", "unread messages", "important slack messages"

**Process**:
1. Fetch unread notifications and mentions
2. Prioritize: Direct mentions > Thread replies > Channel activity
3. Group by urgency and topic
4. Present actionable list with quick reply options

### 5. Standup Collection
**Triggers**: "collect standups", "team standup", "daily standup summary"

**Process**:
1. Fetch standup messages from designated channel
2. Parse: What I did, What I'm doing, Blockers
3. Aggregate team status
4. Highlight blockers and cross-team dependencies
5. Post summary to designated channel (with user confirmation)

---

## Communication Rules

- Never impersonate the user — messages are clearly sent on their behalf
- Always preview before posting
- Respect channel purposes and norms
- Tag team members only when explicitly requested
