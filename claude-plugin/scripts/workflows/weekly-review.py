#!/usr/bin/env python3
"""
Weekly Review Workflow

Generates a weekly cross-department summary with trend analysis, accomplishments,
and planning suggestions. Also updates the learning system's trend analysis.

Connectors used: filesystem, google_sheets, notion

Usage:
    python3 claude-plugin/scripts/workflows/weekly-review.py [--demo]

Environment Variables:
    WORKSPACE_ROOT - Path to workspace root (default: auto-detect)
    PLUGIN_ROOT    - Path to plugin directory (default: auto-detect)
"""

import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path


def detect_workspace_root():
    """Detect workspace root from script location."""
    script_dir = Path(__file__).resolve().parent
    return script_dir.parent.parent.parent


def load_json(filepath):
    """Load a JSON file, return empty dict if not found."""
    try:
        with open(filepath, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def analyze_department_activity(workspace_root, days=7):
    """Analyze file changes per department over the last N days."""
    activity = defaultdict(lambda: {"files_changed": 0, "files_list": []})
    cutoff = datetime.now().timestamp() - (days * 24 * 3600)

    docs_dir = workspace_root / "Docs"
    if docs_dir.exists():
        for dept_dir in docs_dir.iterdir():
            if dept_dir.is_dir() and not dept_dir.name.startswith("."):
                for md_file in dept_dir.rglob("*.md"):
                    if md_file.stat().st_mtime > cutoff:
                        relative = md_file.relative_to(workspace_root)
                        dept_name = dept_dir.name
                        activity[dept_name]["files_changed"] += 1
                        if len(activity[dept_name]["files_list"]) < 5:
                            activity[dept_name]["files_list"].append(str(relative))

    return dict(activity)


def find_stale_placeholders(workspace_root, days_threshold=14):
    """Find [PLACEHOLDER:] tags that haven't been updated."""
    stale = []
    docs_dir = workspace_root / "Docs"
    if docs_dir.exists():
        cutoff = datetime.now().timestamp() - (days_threshold * 24 * 3600)
        for md_file in docs_dir.rglob("*.md"):
            if md_file.stat().st_mtime < cutoff:
                try:
                    content = md_file.read_text(encoding="utf-8", errors="ignore")
                    if "[PLACEHOLDER:" in content:
                        relative = md_file.relative_to(workspace_root)
                        count = content.count("[PLACEHOLDER:")
                        stale.append({"file": str(relative), "placeholder_count": count})
                except (PermissionError, OSError):
                    continue
    return stale[:20]


def analyze_session_patterns(plugin_root):
    """Analyze session patterns for trend insights."""
    patterns = load_json(plugin_root / "context" / "session-patterns.json")
    return {
        "sessions_recorded": patterns.get("sessions_recorded", 0),
        "has_data": patterns.get("sessions_recorded", 0) > 0
    }


def generate_demo_review():
    """Generate a demo weekly review."""
    week_start = (datetime.now() - timedelta(days=7)).strftime("%B %d")
    week_end = datetime.now().strftime("%B %d, %Y")
    return f"""
# Weekly Review — {week_start} to {week_end}
[DEMO MODE] — This shows a sample weekly review. Real data will populate after a week of usage.

## Department Activity Summary (Demo)

| Department | Files Changed | Key Updates |
|---|---|---|
| Strategy | 5 | Updated competitive analysis, new market research |
| Product | 8 | Feature specs for Q2, user research synthesis |
| Sales & Marketing | 12 | Campaign performance review, new case study |
| Operations | 3 | Hiring pipeline update, process improvements |
| Finance | 2 | Monthly financial close, projection updates |

## Key Accomplishments
- Completed competitive analysis for 2 new entrants
- Shipped Q2 product roadmap draft
- Closed 3 deals in sales pipeline
- Screened 5 candidates for Senior Marketing Analyst

## Pending Items
- 3 [PLACEHOLDER:] tags older than 2 weeks need attention
- 1 project status card hasn't been updated (Project Alpha)
- Investor update for Q1 due next week

## Trend Analysis (Demo)
- **Department focus**: Strategy department activity up 30% this week
- **Skill usage**: Meeting intelligence used 5x (most popular skill)
- **Recommendation**: Consider creating a meeting template for recurring client reviews

## Next Week Priorities
1. Complete investor update draft
2. Finalize Q2 campaign launch plan
3. Fill remaining hiring positions
4. Update stale project status cards

---
*Weekly reviews will auto-populate with real data after the first week of plugin usage*
"""


def generate_review(workspace_root, plugin_root, demo_mode=False):
    """Generate the weekly review."""
    if demo_mode:
        return generate_demo_review()

    week_start = (datetime.now() - timedelta(days=7)).strftime("%B %d")
    week_end = datetime.now().strftime("%B %d, %Y")

    sections = [f"# Weekly Review — {week_start} to {week_end}\n"]

    # Department activity
    activity = analyze_department_activity(workspace_root)
    if activity:
        sections.append("## Department Activity (last 7 days)\n")
        sections.append("| Department | Files Changed | Recent Files |")
        sections.append("|---|---|---|")
        for dept, data in sorted(activity.items(), key=lambda x: x[1]["files_changed"], reverse=True):
            files_preview = ", ".join(Path(f).name for f in data["files_list"][:3])
            sections.append(f"| {dept} | {data['files_changed']} | {files_preview} |")
        sections.append("")
    else:
        sections.append("## Department Activity\n- No file changes detected in the last 7 days\n")

    # Stale placeholders
    stale = find_stale_placeholders(workspace_root)
    if stale:
        sections.append("## Pending Placeholders\n")
        total_placeholders = sum(item["placeholder_count"] for item in stale)
        sections.append(f"Found {total_placeholders} [PLACEHOLDER:] tags across {len(stale)} files that need attention:\n")
        for item in stale[:5]:
            sections.append(f"- `{item['file']}` — {item['placeholder_count']} placeholder(s)")
        sections.append("")

    # Session pattern insights
    pattern_data = analyze_session_patterns(plugin_root)
    if pattern_data["has_data"]:
        sections.append("## Usage Patterns\n")
        sections.append(f"- {pattern_data['sessions_recorded']} sessions recorded this period\n")
    else:
        sections.append("## Usage Patterns\n- *Pattern data will populate after more sessions*\n")

    return "\n".join(sections)


def main():
    demo_mode = "--demo" in sys.argv
    workspace_root = Path(os.environ.get("WORKSPACE_ROOT", detect_workspace_root()))
    plugin_root = Path(os.environ.get("PLUGIN_ROOT", workspace_root / "claude-plugin"))

    review = generate_review(workspace_root, plugin_root, demo_mode)
    print(review)


if __name__ == "__main__":
    main()
