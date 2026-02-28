#!/usr/bin/env python3
"""
Activity Report Generator

Generates activity reports by aggregating data from connected workspace tools,
file system changes, and learning system logs.

Usage:
    python3 claude-plugin/scripts/reports/activity-report.py [--days N] [--department DEPT] [--demo]

Arguments:
    --days N         Report period in days (default: 7)
    --department     Filter by department (default: all)
    --demo           Generate demo report

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


def analyze_file_activity(workspace_root, days, department_filter=None):
    """Analyze file modifications across departments."""
    activity = defaultdict(lambda: {"created": 0, "modified": 0, "files": []})
    cutoff = datetime.now().timestamp() - (days * 24 * 3600)

    scan_dirs = {"Docs": workspace_root / "Docs", "Projects": workspace_root / "Projects"}
    for category, base_dir in scan_dirs.items():
        if not base_dir.exists():
            continue
        for md_file in base_dir.rglob("*.md"):
            mtime = md_file.stat().st_mtime
            if mtime > cutoff:
                # Determine department
                relative = md_file.relative_to(workspace_root)
                parts = relative.parts
                dept = parts[1] if len(parts) > 1 and parts[0] == "Docs" else category

                if department_filter and dept.lower() != department_filter.lower():
                    continue

                activity[dept]["modified"] += 1
                if len(activity[dept]["files"]) < 5:
                    activity[dept]["files"].append({
                        "path": str(relative),
                        "modified": datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M")
                    })

    return dict(activity)


def analyze_plugin_activity(plugin_root, days):
    """Analyze plugin usage from learning and suggestion logs."""
    adaptation_log = load_json(plugin_root / "learning" / "adaptation-log.json")
    suggestions_log = load_json(plugin_root / "proactive" / "suggestions-log.json")

    return {
        "adaptations": len(adaptation_log.get("log", [])),
        "suggestions_made": suggestions_log.get("aggregate_stats", {}).get("total_shown", 0),
        "suggestions_accepted": suggestions_log.get("aggregate_stats", {}).get("total_accepted", 0),
        "acceptance_rate": suggestions_log.get("aggregate_stats", {}).get("acceptance_rate")
    }


def generate_demo_report(days):
    """Generate a demo activity report."""
    end_date = datetime.now().strftime("%B %d, %Y")
    start_date = (datetime.now() - timedelta(days=days)).strftime("%B %d")
    return f"""
# Activity Report — {start_date} to {end_date}
[DEMO MODE] — Real data will populate after workspace usage.

## Summary
- **Period**: {days} days
- **Total file changes**: 47
- **Departments active**: 5/6
- **Plugin suggestions**: 12 made, 8 accepted (67% acceptance rate)

## Department Activity

| Department | Files Changed | Key Updates |
|---|---|---|
| Strategy | 8 | 2 competitor analyses, executive summary update |
| Product | 12 | Q2 roadmap, 3 feature specs, user research report |
| Sales & Marketing | 15 | Campaign results, 2 case studies, meeting analyses |
| Operations | 7 | Hiring pipeline update, 2 process SOPs |
| Finance | 5 | Monthly close, projection update, budget review |

## Most Active Files
1. `Docs/SalesAndMarketing/Client-Meetings-Analysis/AI-Projects-Review-Analysis.md` (8 updates)
2. `Docs/Product/roadmap-q2-2026.md` (5 updates)
3. `Docs/Strategy/Competitors/competitive-landscape-summary.md` (4 updates)

## Plugin Learning Activity
- **New preferences learned**: 3
- **Patterns detected**: 5
- **Confidence promotions**: 2 patterns reached high confidence

## Recommendations
1. Strategy department activity is up — consider scheduling a strategy review
2. 3 project status cards need updating
3. Notion sync hasn't run in 5 days — consider running sync

---
*Activity reports auto-populate after workspace usage begins*
"""


def generate_report(workspace_root, plugin_root, days, department_filter, demo_mode):
    """Generate the activity report."""
    if demo_mode:
        return generate_demo_report(days)

    end_date = datetime.now().strftime("%B %d, %Y")
    start_date = (datetime.now() - timedelta(days=days)).strftime("%B %d")

    sections = [f"# Activity Report — {start_date} to {end_date}\n"]

    # File activity
    file_activity = analyze_file_activity(workspace_root, days, department_filter)
    total_changes = sum(d["modified"] for d in file_activity.values())
    sections.append(f"## Summary\n- **Period**: {days} days\n- **Total file changes**: {total_changes}\n- **Departments active**: {len(file_activity)}\n")

    if file_activity:
        sections.append("## Department Activity\n")
        sections.append("| Department | Files Changed | Recent Files |")
        sections.append("|---|---|---|")
        for dept, data in sorted(file_activity.items(), key=lambda x: x[1]["modified"], reverse=True):
            recent = ", ".join(Path(f["path"]).name for f in data["files"][:3])
            sections.append(f"| {dept} | {data['modified']} | {recent} |")
        sections.append("")
    else:
        sections.append("## Department Activity\n- No file changes detected in the report period\n")

    # Plugin activity
    plugin_activity = analyze_plugin_activity(plugin_root, days)
    if plugin_activity["adaptations"] > 0 or plugin_activity["suggestions_made"] > 0:
        sections.append("## Plugin Activity\n")
        sections.append(f"- Adaptations made: {plugin_activity['adaptations']}")
        sections.append(f"- Suggestions offered: {plugin_activity['suggestions_made']}")
        sections.append(f"- Suggestions accepted: {plugin_activity['suggestions_accepted']}")
        if plugin_activity["acceptance_rate"] is not None:
            sections.append(f"- Acceptance rate: {plugin_activity['acceptance_rate']}%")
        sections.append("")

    return "\n".join(sections)


def main():
    demo_mode = "--demo" in sys.argv
    days = 7
    department_filter = None

    for i, arg in enumerate(sys.argv):
        if arg == "--days" and i + 1 < len(sys.argv):
            days = int(sys.argv[i + 1])
        if arg == "--department" and i + 1 < len(sys.argv):
            department_filter = sys.argv[i + 1]

    workspace_root = Path(os.environ.get("WORKSPACE_ROOT", detect_workspace_root()))
    plugin_root = Path(os.environ.get("PLUGIN_ROOT", workspace_root / "claude-plugin"))

    report = generate_report(workspace_root, plugin_root, days, department_filter, demo_mode)
    print(report)


if __name__ == "__main__":
    main()
