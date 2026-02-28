#!/usr/bin/env python3
"""
Trend Report Generator

Analyzes patterns from the learning system and workspace activity to generate
trend insights. Identifies shifts in department focus, tool usage, and workflow
patterns.

Usage:
    python3 claude-plugin/scripts/reports/trend-report.py [--window N] [--demo]

Arguments:
    --window N   Analysis window in days (default: 30)
    --demo       Generate demo trend report

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


def analyze_department_trends(workspace_root, window_days):
    """Analyze department activity trends over the analysis window."""
    current_period = defaultdict(int)
    previous_period = defaultdict(int)

    now = datetime.now().timestamp()
    current_cutoff = now - (window_days * 24 * 3600)
    previous_cutoff = now - (2 * window_days * 24 * 3600)

    docs_dir = workspace_root / "Docs"
    if docs_dir.exists():
        for dept_dir in docs_dir.iterdir():
            if dept_dir.is_dir() and not dept_dir.name.startswith("."):
                for md_file in dept_dir.rglob("*.md"):
                    mtime = md_file.stat().st_mtime
                    if mtime > current_cutoff:
                        current_period[dept_dir.name] += 1
                    elif mtime > previous_cutoff:
                        previous_period[dept_dir.name] += 1

    trends = {}
    all_depts = set(current_period.keys()) | set(previous_period.keys())
    for dept in all_depts:
        current = current_period[dept]
        previous = previous_period[dept]
        if previous > 0:
            change_pct = ((current - previous) / previous) * 100
        elif current > 0:
            change_pct = 100.0
        else:
            change_pct = 0.0

        trends[dept] = {
            "current_period": current,
            "previous_period": previous,
            "change_percent": round(change_pct, 1),
            "trend": "up" if change_pct > 10 else ("down" if change_pct < -10 else "stable")
        }

    return trends


def analyze_learning_trends(plugin_root):
    """Analyze trends in learning system data."""
    patterns = load_json(plugin_root / "learning" / "observed-patterns.json")
    confidence = load_json(plugin_root / "learning" / "confidence-scores.json")
    adaptation = load_json(plugin_root / "learning" / "adaptation-log.json")

    return {
        "total_patterns": len(patterns.get("patterns", [])),
        "high_confidence_patterns": sum(
            1 for s in confidence.get("scores", {}).values()
            if isinstance(s, dict) and s.get("score", 0) >= 0.80
        ),
        "total_adaptations": len(adaptation.get("log", [])),
        "acceptance_rate": adaptation.get("aggregate_metrics", {}).get("acceptance_rate")
    }


def generate_demo_report(window_days):
    """Generate a demo trend report."""
    end_date = datetime.now().strftime("%B %d, %Y")
    start_date = (datetime.now() - timedelta(days=window_days)).strftime("%B %d")
    return f"""
# Trend Report — {start_date} to {end_date}
[DEMO MODE] — Real trend data will populate after {window_days}+ days of usage.

## Department Focus Trends

| Department | Current Period | Previous Period | Change | Trend |
|---|---|---|---|---|
| Strategy | 12 files | 8 files | +50% | UP |
| Product | 15 files | 18 files | -17% | DOWN |
| Sales & Marketing | 20 files | 14 files | +43% | UP |
| Operations | 8 files | 9 files | -11% | DOWN |
| Finance | 5 files | 3 files | +67% | UP |

## Key Trend Insights [ANALYSIS:INFERRED]

1. **Strategy focus increasing**: 50% more activity — likely due to upcoming board meeting or fundraising preparation
2. **Sales & Marketing surge**: 43% increase — may indicate campaign launch or new client acquisition push
3. **Product activity dip**: 17% decrease — possible post-release cooldown or team reallocation
4. **Finance uptick**: 67% increase — likely end-of-quarter financial close

## Learning System Trends
- **Patterns detected**: 12 (5 high confidence, 4 moderate, 3 low)
- **Preference stability**: 85% of preferences unchanged in {window_days} days
- **Suggestion acceptance rate**: 67% (improving from 55% in previous period)

## Recommended Actions
1. **Strategy**: High activity suggests strategic initiative — ensure all strategy docs are current
2. **Sales**: Rising activity — consider creating campaign performance dashboard
3. **Product**: Activity decrease — check if roadmap needs attention or if this is expected
4. **Learning**: 3 patterns approaching high confidence — review for promotion

## Detected Behavioral Patterns
- Mornings: Strategy and product work (8 observations, confidence: 0.75)
- Afternoons: Operations and sales (6 observations, confidence: 0.65)
- Fridays: Financial reviews (4 observations, confidence: 0.55)

---
*Trend reports improve with more usage data. Run weekly for best insights.*
"""


def generate_report(workspace_root, plugin_root, window_days, demo_mode):
    """Generate the trend report."""
    if demo_mode:
        return generate_demo_report(window_days)

    end_date = datetime.now().strftime("%B %d, %Y")
    start_date = (datetime.now() - timedelta(days=window_days)).strftime("%B %d")

    sections = [f"# Trend Report — {start_date} to {end_date}\n"]
    sections.append(f"**Analysis window**: {window_days} days\n")

    # Department trends
    dept_trends = analyze_department_trends(workspace_root, window_days)
    if dept_trends:
        sections.append("## Department Focus Trends\n")
        sections.append("| Department | Current | Previous | Change | Trend |")
        sections.append("|---|---|---|---|---|")
        for dept, data in sorted(dept_trends.items(), key=lambda x: abs(x[1]["change_percent"]), reverse=True):
            trend_icon = {"up": "UP", "down": "DOWN", "stable": "STABLE"}[data["trend"]]
            sections.append(
                f"| {dept} | {data['current_period']} files | {data['previous_period']} files | "
                f"{data['change_percent']:+.1f}% | {trend_icon} |"
            )
        sections.append("")
    else:
        sections.append("## Department Trends\n- Insufficient data for trend analysis\n")

    # Learning trends
    learning = analyze_learning_trends(plugin_root)
    sections.append("## Learning System Status\n")
    sections.append(f"- Behavioral patterns detected: {learning['total_patterns']}")
    sections.append(f"- High-confidence patterns: {learning['high_confidence_patterns']}")
    sections.append(f"- Total adaptations logged: {learning['total_adaptations']}")
    if learning["acceptance_rate"] is not None:
        sections.append(f"- Suggestion acceptance rate: {learning['acceptance_rate']}%")
    sections.append("")

    return "\n".join(sections)


def main():
    demo_mode = "--demo" in sys.argv
    window_days = 30

    for i, arg in enumerate(sys.argv):
        if arg == "--window" and i + 1 < len(sys.argv):
            window_days = int(sys.argv[i + 1])

    workspace_root = Path(os.environ.get("WORKSPACE_ROOT", detect_workspace_root()))
    plugin_root = Path(os.environ.get("PLUGIN_ROOT", workspace_root / "claude-plugin"))

    report = generate_report(workspace_root, plugin_root, window_days, demo_mode)
    print(report)


if __name__ == "__main__":
    main()
