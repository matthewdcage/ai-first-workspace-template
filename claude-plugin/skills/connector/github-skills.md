# GitHub Connector Skills

> **Connector**: GitHub
> **Platform**: Desktop, Web
> **Setup**: Connect via claude.com/connectors

## Skills

### 1. PR Review
**Triggers**: "review PR", "pull request", "code review", "check PR"

**Process**:
1. Access PR via GitHub connector
2. Read: Description, Changed Files, Diff, Comments, CI Status
3. Analyze: Code quality, potential issues, test coverage, documentation
4. Generate structured review: Summary, File-by-File Notes, Suggestions, Approval Recommendation
5. Post review comments if requested (with user confirmation)

### 2. Issue Triage
**Triggers**: "triage issues", "review issues", "issue backlog", "open issues"

**Process**:
1. Fetch open issues from configured repository
2. Categorize: Bug, Feature, Documentation, Question, Enhancement
3. Prioritize: Critical, High, Medium, Low
4. Identify: Stale issues, duplicates, issues needing more info
5. Suggest labels and assignees based on patterns

### 3. Code Search
**Triggers**: "search code", "find in codebase", "where is this function", "code reference"

**Process**:
1. Determine search scope (repo, path, language)
2. Search via GitHub connector
3. Present: File path, line numbers, surrounding context
4. Cross-reference with related code and documentation

### 4. Release Notes
**Triggers**: "release notes", "changelog", "what changed", "version summary"

**Process**:
1. Fetch commits/PRs since last release tag
2. Categorize changes: Features, Bug Fixes, Breaking Changes, Documentation
3. Generate human-readable release notes
4. Follow conventional changelog format
5. Draft for user review before publishing

---

## Git Workflow Rules

**CRITICAL — from workspace `.cursorrules`:**
- **NEVER push** without explicit user confirmation
- **NEVER commit** until user indicates work is complete
- Suggest commits when a coherent set of changes is ready
- Respect developer workflows — technical repos require review processes
- No direct changes to `Dev/` repositories without developer onboarding
