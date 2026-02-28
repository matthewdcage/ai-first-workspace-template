# Document Lifecycle — Cross-Functional Skill

> **Scope**: Create, review, approve, and distribute documents across platforms
> **Connectors**: filesystem, google_docs, notion, slack, email
> **Enforces**: canonical_tags, reference_tags, source_tracking

## Phases

### Phase 1: Document Creation
**Triggers**: "create document", "write report", "draft memo", "new document"

**Process**:
1. **Determine Type and Template**:
   - Strategy: Executive summary, competitive analysis, investor update
   - Product: Spec, roadmap update, research synthesis
   - Sales/Marketing: Campaign plan, case study, meeting brief
   - Operations: SOP, evaluation report, metrics review
   - Finance: Financial model, budget analysis, projection
2. **Gather Context**:
   - Read relevant department `.cursorrules` for formatting standards
   - Check for existing canonical definitions to reference (`[REF:]`)
   - Load user format preferences from learning system
3. **Create with Quality**:
   - Mark new definitions as `[CANONICAL]`
   - Reference existing definitions with `[REF: path#section]`
   - Source all claims with `[CONFIRMED: source]`
   - Mark gaps as `[PLACEHOLDER: owner]`
   - Include "Last Updated" timestamp
4. **Save to Appropriate Location**:
   - Place in correct department folder per workspace structure
   - Use clear, descriptive filename following workspace naming conventions

### Phase 2: Document Review
**Triggers**: "review document", "check this doc", "give feedback", "proofread"

**Process**:
1. **Read Document**: Load full content
2. **Check Information Architecture**:
   - Are all `[CANONICAL]` tags appropriate?
   - Do all `[REF:]` tags point to valid files?
   - Are there unsourced claims that need `[CONFIRMED:]` or `[PLACEHOLDER:]`?
3. **Check Content Quality**:
   - Consistency with department standards
   - Accuracy of cross-references
   - Completeness (no orphan statements)
   - Formatting per user preferences
4. **Generate Feedback**: Structured review with specific suggestions per section

### Phase 3: Document Distribution
**Triggers**: "share document", "distribute report", "send to team"

**Process**:
1. **Determine Audience and Channel**:
   - Internal team → Slack channel + Notion
   - Executives → Google Docs with sharing + email
   - Clients → Email with attachment + Google Drive link
2. **Format for Platform**:
   - Slack: Summary with link to full document
   - Email: Executive summary in body, full doc attached
   - Notion: Full content as Notion page
3. **Get Confirmation**: Preview distribution plan, get user approval
4. **Execute Distribution**: Send via confirmed channels
5. **Log**: Record distribution in workspace context

---

## Information Architecture Enforcement

All documents produced through this skill MUST follow workspace rules:

| Tag | Usage |
|---|---|
| `[CANONICAL]` | First/authoritative definition of any concept |
| `[REF: path#section]` | Reference to a canonical definition elsewhere |
| `[CONFIRMED: source]` | Information verified by a reliable source |
| `[PLACEHOLDER: owner]` | Information to be filled, with clear ownership |
| `[ADAPTED from source: "old" -> "new"]` | Context-adapted version of canonical content |
| `[ANALYSIS:INFERRED]` | Plugin-derived insight (not user-confirmed) |

## Quality Checklist

Before finalizing any document:
- [ ] All claims sourced (`[CANONICAL]`, `[REF:]`, or `[CONFIRMED:]`)
- [ ] No orphan statements (unsourced facts)
- [ ] Placeholders have clear owners
- [ ] Cross-references resolve to existing files
- [ ] Formatting matches department and user preferences
- [ ] "Last Updated" timestamp included
