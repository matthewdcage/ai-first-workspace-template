# Sales & Marketing Department Skills

> **Department**: Sales & Marketing
> **Context File**: `Docs/SalesAndMarketing/.cursorrules`
> **Key Paths**: `Docs/SalesAndMarketing/`, `Docs/SalesAndMarketing/Client-Meetings-Analysis/`, `Sales Calls/`

## Skills

### 1. Meeting Preparation
**Triggers**: "meeting prep", "client prep", "discovery call prep", "prepare for meeting"
**Connectors**: filesystem, notion, calendar, slack
**Complexity**: Medium | **Duration**: 10-15min

**Process**:
1. Check calendar for upcoming meeting details (attendees, agenda)
2. Pull client history from `Docs/SalesAndMarketing/Client-Meetings-Analysis/`
3. Review related project status from `Projects/`
4. Surface competitive positioning relevant to client's industry
5. Generate brief with: Client Background, Previous Interactions, Key Topics, Talking Points, Questions to Ask

**Output**: Pre-meeting briefing document.

### 2. Campaign Design
**Triggers**: "design campaign", "marketing campaign", "content strategy", "go-to-market"
**Connectors**: filesystem, notion, google_docs, slack
**Complexity**: High | **Duration**: 20-30min

**Process**:
1. Review existing campaigns in `Docs/SalesAndMarketing/Media activities/`
2. Align with strategic positioning from `Docs/Strategy/`
3. Define: Target Audience, Key Messages, Channels, Content Calendar, Success Metrics
4. Reference client testimonials from `Docs/SalesAndMarketing/client-testimonials-case-studies.md`
5. Use competitive differentiators from `Docs/Strategy/Competitors/`

**Output**: Campaign plan document with timeline and deliverables.

### 3. Lead Scoring
**Triggers**: "score lead", "lead qualification", "prospect evaluation", "pipeline review"
**Connectors**: filesystem, notion, google_sheets
**Complexity**: Medium | **Duration**: 5-10min

**Process**:
1. Gather lead information from CRM/Notion
2. Score against qualification criteria: Budget, Authority, Need, Timeline (BANT)
3. Cross-reference with ideal customer profile from Strategy docs
4. Use `scripts/check_range.py` for score range validation
5. Recommend: Pursue, Nurture, or Deprioritize

**Output**: Lead scoring assessment with recommendation.

### 4. Testimonial Collection
**Triggers**: "collect testimonial", "case study", "client success story", "customer reference"
**Connectors**: filesystem, notion, slack, email
**Complexity**: Medium | **Duration**: 10-20min

**Process**:
1. Identify candidates from `Docs/SalesAndMarketing/Client-Meetings-Analysis/`
2. Draft outreach message tailored to client relationship
3. Prepare structured interview questions
4. Update `Docs/SalesAndMarketing/client-testimonials-case-studies.md` with new testimonial
5. Tag with `[CONFIRMED: client name, date]`

**Output**: Testimonial draft and outreach materials.

---

## Department-Specific Rules

- Load `Docs/SalesAndMarketing/.cursorrules` before executing
- Always reference competitive positioning from Strategy department
- Use client-appropriate language (not internal jargon)
- Respect client data privacy — only reference client-specific information when relevant
- Existing meeting processor: `scripts/sales-meeting-automation/demo-meeting-processor.py`
