# Data Platform Connector Skills

> **Connectors**: Google Sheets (primary), Code Execution, Web Search (for benchmarks)
> **Platform**: Desktop (code execution), All (sheets/web)

## Skills

### 1. Analytics Query
**Triggers**: "analytics", "query data", "data analysis", "metrics query"

**Process**:
1. Identify data source (Google Sheets, local CSV, API)
2. Understand the question — what metric, time range, dimensions
3. Formulate query or analysis approach
4. Execute via appropriate connector (Sheets API or Python script)
5. **MANDATORY**: Use `scripts/check_range.py` for all numerical range validations
6. Present results with source attribution `[CONFIRMED: {data_source}]`

**Output**: Structured data analysis with source tags.

### 2. Dashboard Creation
**Triggers**: "create dashboard", "metrics dashboard", "KPI overview", "data visualization"

**Process**:
1. Gather requirements: What metrics, audience, refresh frequency
2. Pull data from connected sources
3. Create structured markdown dashboard with:
   - Key metric cards (value, trend, status)
   - Tables for detailed breakdowns
   - Trend indicators (up/down/flat)
4. Save to appropriate department folder
5. Tag data sources with `[REF:]` and `[CONFIRMED:]`

**Output**: Markdown-based dashboard document.

### 3. Trend Analysis
**Triggers**: "trend analysis", "data trends", "pattern in data", "historical comparison"

**Process**:
1. Pull historical data from connected sources
2. Identify patterns: growth/decline, seasonality, anomalies
3. Use `scripts/check_range.py` for all threshold comparisons
4. Calculate: period-over-period change, moving averages, standard deviations
5. Present findings with confidence levels and caveats
6. Mark inferred insights as `[ANALYSIS:INFERRED]`

**Output**: Trend analysis report with data-backed insights.

### 4. Data Export
**Triggers**: "export data", "download report", "generate CSV", "data dump"

**Process**:
1. Identify source data and format requirements
2. Extract data from connected source
3. Format as requested (CSV, markdown table, JSON)
4. Save to workspace or share via connector
5. Include metadata: source, date range, filters applied

**Output**: Formatted data export file.

---

## Data Integrity Rules

- **NEVER** fabricate data points — every number must have a source
- Always use `scripts/check_range.py` for range comparisons
- Tag all data with source: `[CONFIRMED: {source, date}]`
- Mark derived calculations as `[ANALYSIS:INFERRED]` with methodology
- When data is missing, use `[PLACEHOLDER: {owner}]` — never fill with estimates unless explicitly requested
