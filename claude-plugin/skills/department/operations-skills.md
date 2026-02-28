# Operations Department Skills

> **Department**: Operations (including Hiring)
> **Context File**: `Docs/Operations/.cursorrules`, `Docs/Operations/Hiring/.cursorrules`
> **Key Paths**: `Docs/Operations/`, `Docs/Operations/Hiring/`

## Skills

### 1. Candidate Screening
**Triggers**: "evaluate candidate", "screen candidate", "screening evaluation", "review CV"
**Connectors**: filesystem, notion
**Complexity**: High | **Duration**: 15-25min

**Process**:
1. Load hiring rules from `Docs/Operations/Hiring/Global-Rules/`:
   - `General-Hiring-Policy.md`
   - `Interview-Guidelines.md`
   - `Scoring-Framework.md`
2. Load position-specific rules from `Docs/Operations/Hiring/Job-Openings/{Position}/`:
   - `Position-Description.md`
   - `Role-Competency-Matrix.md`
   - `Scoring-Rules.md`
3. Read candidate materials (CV, interview transcripts)
4. Apply scoring framework systematically
5. Use `scripts/check_range.py` for score range validation
6. Generate evaluation following existing agent format

**Existing Agents** [REF: Docs/Operations/Hiring/Job-Openings/Senior-Marketing-Analyst/]:
- Screening Agent: `Screening-Agent/agent.py` + `agent-config.json` + `agent-prompt.md`
- Full Evaluation Agent: `Full Evaluation Agent/`

**Output**: Structured candidate evaluation report with scores.

**Anti-hallucination**: Never invent qualifications or experience. Mark unclear items as `[PLACEHOLDER: verify with candidate]`.

### 2. Process Documentation
**Triggers**: "document process", "create SOP", "standard operating procedure", "workflow documentation"
**Connectors**: filesystem, notion, google_docs
**Complexity**: Medium | **Duration**: 15-30min

**Process**:
1. Interview user about the process steps
2. Document in structured format: Purpose, Scope, Steps, Roles, Metrics, Exceptions
3. Cross-reference with existing processes in `Docs/Operations/`
4. Tag new process definitions as `[CANONICAL]`
5. Identify automation opportunities

**Output**: Standard operating procedure document.

### 3. Metrics Review
**Triggers**: "operational metrics", "team metrics", "KPI review", "performance dashboard"
**Connectors**: filesystem, google_sheets, slack
**Complexity**: Medium | **Duration**: 10-15min

**Process**:
1. Pull metrics from department dashboards and sheets
2. Use `scripts/check_range.py` for all range comparisons
3. Identify trends and anomalies
4. Compare against targets and historical performance
5. Surface items needing attention

**Output**: Metrics review summary with trend indicators.

### 4. Hiring Pipeline Review
**Triggers**: "hiring pipeline", "recruitment status", "candidate pipeline", "hiring dashboard"
**Connectors**: filesystem, notion, google_sheets
**Complexity**: Medium | **Duration**: 10-15min

**Process**:
1. Scan `Docs/Operations/Hiring/Job-Openings/` for active positions
2. Read `Candidate-Pipeline.md` for each position
3. Aggregate pipeline statistics: candidates per stage, time in stage, conversion rates
4. Identify bottlenecks and positions needing attention
5. Generate dashboard summary

**Output**: Hiring pipeline dashboard.

---

## Department-Specific Rules

- Load `Docs/Operations/.cursorrules` for general operations
- Load `Docs/Operations/Hiring/.cursorrules` for hiring-specific tasks
- Use existing agent configurations (agent-config.json) when available — do not reinvent scoring
- Apply scoring frameworks consistently across all candidates
- All numerical evaluations must use `scripts/check_range.py`
