# Product Department Skills

> **Department**: Product
> **Context File**: `Docs/Product/.cursorrules`
> **Key Paths**: `Docs/Product/`

## Skills

### 1. Spec Writing
**Triggers**: "write spec", "feature specification", "product requirements", "PRD"
**Connectors**: filesystem, github, notion
**Complexity**: High | **Duration**: 20-45min

**Process**:
1. Gather requirements from conversation and existing documents
2. Reference product architecture from `Docs/Product/`
3. Check for related specs and cross-reference with `[REF:]` tags
4. Structure: Problem Statement → Goals → Requirements → Technical Approach → Success Metrics → Open Questions
5. Mark new definitions as `[CANONICAL]` in the spec
6. Mark assumptions as `[PLACEHOLDER: PM/Eng to confirm]`

**Output**: Structured product specification document.

### 2. Roadmap Update
**Triggers**: "update roadmap", "roadmap planning", "prioritize features", "roadmap review"
**Connectors**: filesystem, notion, github
**Complexity**: Medium | **Duration**: 15-20min

**Process**:
1. Load current roadmap from `Docs/Product/`
2. Cross-reference with strategy priorities from `Docs/Strategy/`
3. Incorporate customer feedback and market research
4. Apply prioritization framework (impact vs effort)
5. Update timeline and dependencies

**Output**: Updated roadmap document with change annotations.

### 3. User Research Synthesis
**Triggers**: "user research", "customer feedback", "user insights", "research synthesis"
**Connectors**: filesystem, notion, google_sheets
**Complexity**: Medium | **Duration**: 15-25min

**Process**:
1. Aggregate research from `Docs/Strategy/User-Research/` and customer feedback sources
2. Identify recurring themes and pain points
3. Quantify where possible (use `scripts/check_range.py` for metrics)
4. Map insights to product areas and roadmap items
5. Tag all findings with `[CONFIRMED: {source}]`

**Output**: Research synthesis report with actionable insights.

### 4. Feature Prioritization
**Triggers**: "prioritize features", "feature scoring", "backlog review", "what to build next"
**Connectors**: filesystem, google_sheets, notion
**Complexity**: Medium | **Duration**: 10-20min

**Process**:
1. List candidate features from roadmap and backlog
2. Score against framework: Strategic Alignment, Customer Impact, Technical Effort, Revenue Impact
3. Use `scripts/check_range.py` for score range validation
4. Generate ranked priority list with rationale
5. Identify dependencies and blockers

**Output**: Prioritized feature list with scoring matrix.

---

## Department-Specific Rules

- Load `Docs/Product/.cursorrules` before executing any product skill
- Respect the product architecture distinction between V1 (foundation) and V2 (AI layer)
- Cross-reference with Strategy for competitive positioning context
- Cross-reference with Dev/ for technical feasibility
- Use `[CANONICAL]` tags for new product definitions
