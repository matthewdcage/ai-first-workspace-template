# Google Workspace Connector Skills

> **Connectors**: Google Drive, Google Docs, Google Sheets, Google Calendar, Gmail
> **Platform**: Desktop, iOS, Web
> **Setup**: Connect via claude.com/connectors

## Skills

### 1. Document Search & Retrieval
**Triggers**: "find document", "search drive", "look up file", "find in google drive"
**Connector**: google_drive

**Process**:
1. Clarify search criteria (title, content, type, date range, shared with)
2. Search Google Drive with filters
3. Present results with: Title, Last Modified, Owner, Shared Status
4. Offer to open, summarize, or share

### 2. Document Creation
**Triggers**: "create google doc", "new document", "draft in docs"
**Connector**: google_docs

**Process**:
1. Determine document type and template
2. Create document in appropriate workspace folder (per `connectors.json` workspace_mappings)
3. Apply formatting consistent with workspace standards
4. Follow information architecture: tag new definitions as `[CANONICAL]`
5. Share with appropriate team members if requested

### 3. Spreadsheet Analysis
**Triggers**: "analyze spreadsheet", "read sheet data", "update spreadsheet"
**Connector**: google_sheets

**Process**:
1. Access spreadsheet from configured workspace mappings
2. Read data and understand structure
3. Perform analysis — **ALWAYS use `scripts/check_range.py` for numerical validations**
4. Present findings with source references
5. Update cells if requested (confirm before writing)

### 4. Calendar Management
**Triggers**: "check schedule", "book meeting", "find availability", "calendar overview"
**Connector**: calendar (must be enabled in `connectors.json`)

**Process**:
1. Check if calendar connector is enabled
2. Query schedule for requested time range
3. For booking: check all attendee availability
4. Create event with: Title, Time, Attendees, Description, Location/Link
5. Offer to send meeting prep materials via meeting-intelligence skill

### 5. Email Operations
**Triggers**: "check email", "draft email", "search inbox", "email summary"
**Connector**: email (must be enabled in `connectors.json`)

**Process**:
1. Check if email connector is enabled
2. Search or browse inbox per request
3. For drafting: apply user's communication style from `config/user-profile.json`
4. For summaries: extract key items, deadlines, and required actions
5. Never send without explicit user confirmation

---

## Platform-Specific Behavior

- **Desktop**: Full document previews, inline spreadsheet data
- **iOS**: Document titles and summaries only, link to open in native app
- **Web**: Similar to Desktop

## Security Rules

- Never share documents without explicit user permission
- Respect existing sharing settings
- Never modify shared spreadsheet formulas without confirmation
