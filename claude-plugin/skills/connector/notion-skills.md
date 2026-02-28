# Notion Connector Skills

> **Connector**: Notion
> **Platform**: Desktop, iOS, Web
> **Existing Scripts**: `scripts/notion-integration/` (notion-fetch.py, notion-send-meeting-analysis.py, setup-notion-integration.py, notion-bootstrap.py)

## Skills

### 1. Database Query
**Triggers**: "query notion", "notion database", "search notion", "find in notion"

**Process**:
1. Identify target database from `connectors.json` workspace_mappings
2. Build query with filters and sorts
3. Fetch results using Notion connector
4. Present in tabular format (Desktop) or condensed list (iOS)
5. Offer to update or create new entries

### 2. Page Creation
**Triggers**: "create notion page", "new notion doc", "add to notion"

**Process**:
1. Determine target database or parent page
2. Structure content with Notion-native formatting (headings, toggles, callouts)
3. Apply workspace information architecture tags where applicable
4. Create page via connector
5. Return link to created page

### 3. Meeting Notes Sync
**Triggers**: "sync meeting notes", "send to notion", "update notion with meeting"

**Process**:
1. Check for meeting analysis output (from meeting-intelligence skill)
2. Format for Notion: structured with sections, action items, decisions
3. Use existing script: `scripts/notion-integration/notion-send-meeting-analysis.py`
4. Confirm sync completion with page link

**Integration**: Extends `scripts/notion-integration/notion-send-meeting-analysis.py`

### 4. Project Tracking
**Triggers**: "notion project status", "update project in notion", "project tracker"

**Process**:
1. Access project database from workspace_mappings
2. Read current project status entries
3. Update status, dates, notes as requested
4. Generate summary of all active projects if requested
5. Flag overdue items

### 5. Bidirectional Sync
**Triggers**: "sync notion", "notion sync", "update from notion"

**Process**:
1. Pull latest from Notion databases → compare with local workspace files
2. Identify changes in both directions
3. Apply conflict resolution per `connectors.json` sync_settings (default: notion_wins)
4. Present sync summary with change list
5. Confirm before applying local changes

**Integration**: Extends `scripts/notion-integration/notion-fetch.py`

---

## Demo Mode

When `NOTION_TOKEN` is not configured:
```
[DEMO MODE] Notion is not yet connected.
Setup: Run `python3 scripts/notion-integration/setup-notion-integration.py` or connect via claude.com/connectors

Simulated result:
{mock data matching expected output format}
```
