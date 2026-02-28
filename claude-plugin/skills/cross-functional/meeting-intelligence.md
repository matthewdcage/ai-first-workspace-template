# Meeting Intelligence — Cross-Functional Skill

> **Scope**: Pre-meeting preparation, live meeting support, post-meeting analysis and follow-ups
> **Connectors**: filesystem, calendar, notion, slack, email
> **Existing Scripts**: `scripts/sales-meeting-automation/demo-meeting-processor.py`
> **Data Sources**: `Projects/Transcripts/`, `Projects/Fireflies-Transcripts/`

## Phases

### Phase 1: Pre-Meeting Preparation
**Triggers**: "prep for meeting", "meeting prep", "prepare briefing for {meeting_name}"

**Process**:
1. **Calendar Check**: Pull meeting details — attendees, time, agenda, location
2. **Attendee Context**:
   - Search workspace for files mentioning attendees
   - Check `Docs/SalesAndMarketing/Client-Meetings-Analysis/` for client history
   - Pull project status from `Projects/` if relevant
   - Check Notion for CRM data on attendees
3. **Topic Context**:
   - Surface relevant documents from the active department
   - Pull competitive positioning if client-facing meeting
   - Load any previous meeting notes/transcripts
4. **Generate Briefing**:
   - **Desktop**: Full structured briefing with Attendee Profiles, Previous Interactions, Key Topics, Talking Points, Questions to Ask, Related Documents
   - **iOS**: Condensed bullet briefing — Top 5 talking points, 3 key questions, critical context

**Output**: Pre-meeting briefing document.

### Phase 2: Meeting Analysis
**Triggers**: "analyze meeting", "process transcript", "meeting summary", "what was decided"

**Process**:
1. **Ingest Transcript**: Read from workspace path or user-provided text
   - Supported sources: Fireflies, manual transcription, uploaded file
   - Check `Projects/Transcripts/` and `Projects/Fireflies-Transcripts/` for recent transcripts
2. **Extract Structure**:
   - Participants and their roles
   - Topics discussed (mapped to agenda if available)
   - Decisions made
   - Action items (with assignees and deadlines)
   - Questions raised (answered and unanswered)
   - Follow-up commitments
3. **Contextualize**:
   - Map decisions to relevant department documents
   - Link action items to existing projects/tasks
   - Identify references to competitors, clients, or products
4. **Generate Summary**: Structured meeting analysis with clear sections

**Integration**: Extends `scripts/sales-meeting-automation/demo-meeting-processor.py` for Fireflies-sourced transcripts.

### Phase 3: Post-Meeting Follow-Up
**Triggers**: "send follow-up", "meeting follow-up", "action items from meeting"

**Process**:
1. **Distribute Notes**:
   - Sync to Notion via `scripts/notion-integration/notion-send-meeting-analysis.py`
   - Post summary to relevant Slack channel (with user confirmation)
   - Share via email to external attendees (with user confirmation)
2. **Create Tasks**:
   - Convert action items to tasks in Notion/project tracker
   - Set reminders for deadlines
3. **Update Context**:
   - Update `Docs/SalesAndMarketing/Client-Meetings-Analysis/` if client meeting
   - Update project status if project-related
   - Record decisions in relevant department documents with `[CONFIRMED: meeting, date]` tags

---

## Adaptive Behavior

Based on learned patterns:
- If user always preps for Monday meetings on Friday → proactively suggest Friday afternoon prep
- If user prefers bullet-point meeting notes → default to that format
- If user always sends follow-ups within 1 hour → suggest immediate follow-up
- Track which meeting types get the most engagement → prioritize prep for those
