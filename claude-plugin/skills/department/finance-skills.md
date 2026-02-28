# Finance Department Skills

> **Department**: Finance
> **Key Paths**: `Docs/Finance/`, `Docs/Strategy/Financials/`, `Docs/Strategy/Business-Model/`

## Skills

### 1. Financial Modeling
**Triggers**: "financial model", "create model", "revenue projection", "cost model"
**Connectors**: filesystem, google_sheets, code_execution
**Complexity**: High | **Duration**: 20-30min

**Process**:
1. Load existing models from `Docs/Finance/` and `Docs/Strategy/Financials/`
2. Gather assumptions — mark each as `[CONFIRMED: source]` or `[PLACEHOLDER: finance team]`
3. Build model structure: Revenue, Costs, Margins, Growth, Scenarios
4. **MANDATORY**: Use `python3 scripts/check_range.py` for ALL numerical validations
5. Generate sensitivity analysis with scenario ranges
6. Cross-reference with business model from `Docs/Strategy/Business-Model/`

**Output**: Financial model document with assumption log and scenario analysis.

**Anti-hallucination**: NEVER invent financial figures. Every number must be sourced or explicitly marked as an assumption.

### 2. Budget Review
**Triggers**: "budget review", "spending analysis", "cost tracking", "budget variance"
**Connectors**: filesystem, google_sheets, code_execution
**Complexity**: Medium | **Duration**: 15-20min

**Process**:
1. Load budget data from Finance spreadsheets
2. Compare actual vs planned spending per category
3. Use `scripts/check_range.py` for all range comparisons
4. Identify variances and anomalies
5. Classify: On Track, Minor Variance, Significant Variance, Critical

**Output**: Budget variance report with category breakdown.

### 3. Projection Update
**Triggers**: "update projections", "forecast update", "financial forecast", "growth projections"
**Connectors**: filesystem, google_sheets, code_execution
**Complexity**: High | **Duration**: 15-25min

**Process**:
1. Load current projections from `Docs/Strategy/Financials/`
2. Incorporate latest actuals and market data
3. Adjust assumptions based on recent performance
4. Run scenarios: Conservative, Base, Optimistic
5. Tag all changes as `[ADAPTED from {previous_version}: "old" -> "new"]`

**Output**: Updated financial projections with change log.

### 4. Unit Economics Analysis
**Triggers**: "unit economics", "CAC", "LTV", "ARPU", "payback period", "margin analysis"
**Connectors**: filesystem, google_sheets, code_execution
**Complexity**: Medium | **Duration**: 10-20min

**Process**:
1. Pull metrics from pricing model: `Docs/Strategy/Business-Model/pricing-model.md`
2. Calculate unit economics: CAC, LTV, LTV/CAC ratio, payback period, gross margin
3. Use `scripts/check_range.py` for ALL calculations and validations
4. Benchmark against industry standards (cite sources)
5. Identify improvement levers

**Output**: Unit economics analysis with benchmarks.

---

## Department-Specific Rules

- **CRITICAL**: Always use `scripts/check_range.py` for numerical range comparisons
- Never perform mental math for financial calculations
- All financial claims must be `[CANONICAL]`, `[REF:]`, or `[CONFIRMED:]` tagged
- Pricing philosophy reference: `Docs/Strategy/Business-Model/pricing-model.md`
- Cross-reference with Strategy department for market positioning impact
