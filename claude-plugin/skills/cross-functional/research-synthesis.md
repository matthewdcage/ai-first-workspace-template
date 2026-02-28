# Research Synthesis — Cross-Functional Skill

> **Scope**: Multi-source research combining web search, internal documents, competitor data, and analytics
> **Connectors**: web_search, filesystem, notion, google_drive
> **Output Path**: Typically `Docs/Strategy/Competitors/` for competitive research

## Research Types

### 1. Competitive Research
**Triggers**: "research competitor", "analyze {company}", "competitive landscape"

**Process** [REF: .cursorrules#competitor-analysis-process]:
1. **Web Research** — Comprehensive search across:
   - Product pages and pricing
   - Founder backgrounds and LinkedIn profiles
   - Press releases and funding announcements
   - G2/Capterra reviews and ratings
   - Case studies and customer testimonials
   - Strategic partnerships and integrations
   - Industry analyst coverage
2. **Internal Cross-Reference**:
   - Check `Docs/Strategy/Competitors/` for existing analyses
   - Reference positioning rules from root `.cursorrules`
   - Cross-reference with product competitive features
3. **Synthesize**: Create `[company-name]-analysis.md` using 11-section template:
   - Company Overview, Product/Service, Target Market, Pricing, Technology Stack, Team & Funding, Key Strengths, Key Weaknesses, Competitive Positioning, Threat Level, Bottom Line
4. **Update**: Update `Docs/Strategy/Competitors/competitive-landscape-summary.md`

**Source tagging**: Every claim from web research gets `[CONFIRMED: {URL or source}]`.

### 2. Market Research
**Triggers**: "market analysis", "industry research", "market trends", "industry overview"

**Process**:
1. **Define Scope**: Market segment, geography, time range
2. **Multi-Source Gathering**:
   - Web search: Industry reports, analyst estimates, market data
   - Internal: Strategy docs, financial models, client feedback
   - Google Sheets: Historical data and metrics
3. **Synthesize Findings**:
   - Market size and growth (TAM/SAM/SOM)
   - Key trends and drivers
   - Competitive dynamics
   - Opportunities and threats
4. **Validate**: Use `scripts/check_range.py` for all numerical claims
5. **Document**: Full research report with source attribution

### 3. Technology Research
**Triggers**: "technology assessment", "evaluate technology", "tech stack review"

**Process**:
1. **Define Requirements**: What problem, constraints, evaluation criteria
2. **Research**: Web search for options, documentation, comparisons, community feedback
3. **Internal Context**: Check `Dev/` for current tech stack, `Docs/Product/` for technical constraints
4. **Evaluate**: Create comparison matrix with weighted scoring
5. **Recommend**: Structured recommendation with trade-offs

### 4. Multi-Source Synthesis
**Triggers**: "synthesize findings", "combine research", "research overview"

**Process**:
1. **Gather Sources**: Pull from multiple source types (web, internal docs, data, meetings)
2. **Deduplicate**: Identify overlapping information, keep canonical versions
3. **Reconcile Conflicts**: When sources disagree, note both with confidence levels
4. **Synthesize**: Create unified narrative with:
   - Key Findings (ranked by confidence)
   - Supporting Evidence (with sources)
   - Contradictions/Uncertainties
   - Implications and Recommendations
5. **Tag Appropriately**:
   - `[CONFIRMED: {source}]` for verified claims
   - `[ANALYSIS:INFERRED]` for synthesized insights
   - `[PLACEHOLDER: research needed]` for gaps

---

## Research Quality Standards

- **Minimum 5 sources** for competitive analysis
- **Minimum 3 sources** for market claims
- **Every statistic** must have a source tag
- **Every inference** must be tagged `[ANALYSIS:INFERRED]`
- **Contradictory data** must be noted, not silently resolved
- **Recency bias check**: Prefer data from last 12 months, flag older data
- **Numerical validation**: Use `scripts/check_range.py` for all range comparisons

## Adaptive Behavior

Based on learned patterns:
- If user prefers executive summaries → lead with 3-bullet summary before details
- If user always requests specific competitor sections → prioritize those
- If user frequently researches a specific market → maintain running context
- Track which research formats get the best feedback → default to those
