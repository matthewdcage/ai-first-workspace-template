# Strategy Department Skills

> **Department**: Strategy
> **Context File**: `Docs/Strategy/.cursorrules`
> **Key Paths**: `Docs/Strategy/Company-Overview/`, `Docs/Strategy/Competitors/`, `Docs/Strategy/Business-Model/`

## Skills

### 1. Competitive Analysis
**Triggers**: "analyze competitor", "competitive landscape", "market comparison", "threat assessment"
**Connectors**: web_search, filesystem, google_sheets
**Complexity**: High | **Duration**: 20-30min

**Process** [REF: Docs/Strategy/.cursorrules#competitor-analysis-process]:
1. **Research**: Comprehensive web search — product pages, pricing, founders, funding, G2/Capterra reviews, case studies, partnerships
2. **Create**: `[company-name]-analysis.md` in `Docs/Strategy/Competitors/` using 11-section template:
   - Company Overview, Product/Service, Target Market, Pricing, Technology, Team/Funding, Strengths, Weaknesses, Competitive Positioning, Threat Level, Bottom Line
3. **Classify**: Categorize competitor into established competitive categories
4. **Update**: Update `Docs/Strategy/Competitors/competitive-landscape-summary.md` with cross-references

**Output**: Structured markdown report with `[CONFIRMED: web search]` source tags on all claims.

**Anti-hallucination**: Never invent funding amounts, team sizes, or revenue figures. Mark unknowns as `[PLACEHOLDER: research needed]`.

### 2. Market Sizing
**Triggers**: "market size", "TAM", "SAM", "SOM", "addressable market"
**Connectors**: web_search, filesystem, google_sheets
**Complexity**: High | **Duration**: 15-25min

**Process**:
1. Research industry reports, analyst estimates, public data
2. Build bottom-up and top-down estimates
3. Use `scripts/check_range.py` for all numerical range validations
4. Create market sizing document with clear methodology
5. Tag all data points with sources: `[CONFIRMED: {source}]`

**Output**: Market sizing analysis with TAM/SAM/SOM breakdown.

### 3. Investor Update Draft
**Triggers**: "investor update", "investor letter", "quarterly update"
**Connectors**: filesystem, google_sheets, google_docs
**Complexity**: Medium | **Duration**: 15-20min

**Process**:
1. Pull latest metrics from `Docs/Strategy/Financials/` and `Docs/Strategy/Investor-Updates/`
2. Reference recent competitive developments from `Docs/Strategy/Competitors/`
3. Incorporate product milestones from `Docs/Product/`
4. Draft update following previous investor communication style
5. All metrics must be `[CANONICAL]` or `[REF:]` tagged

**Output**: Draft investor update letter.

### 4. Executive Briefing
**Triggers**: "executive briefing", "exec summary", "board prep", "leadership update"
**Connectors**: filesystem, google_sheets, slack
**Complexity**: Medium | **Duration**: 10-15min

**Process**:
1. Pull `Docs/Strategy/executive-summary.md` as baseline
2. Cross-reference with recent department activity
3. Surface key decisions needed and risks
4. Format as one-page executive overview

**Output**: One-page executive briefing document.

---

## Department-Specific Rules

- Always load `Docs/Strategy/.cursorrules` before executing any strategy skill
- Follow the positioning rules defined in the root `.cursorrules`
- Use competitive messaging templates for any positioning-related content
- Reference `executive-summary.md` as the canonical one-page company overview
- Cross-reference with Product, Finance, and Market Analysis documents
