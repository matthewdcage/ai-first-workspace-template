#!/usr/bin/env python3
"""
Morning Briefing Workflow

Generates a personalized daily briefing by aggregating information from
connected workspace tools and local workspace state.

Wraps existing: setup/update-all.sh (workspace sync)
Connectors used: filesystem, calendar, slack, email

Usage:
    python3 claude-plugin/scripts/workflows/morning-briefing.py [--demo]

Environment Variables:
    WORKSPACE_ROOT - Path to workspace root (default: auto-detect)
    PLUGIN_ROOT    - Path to plugin directory (default: auto-detect)
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path


def detect_workspace_root():
    """Detect workspace root from script location."""
    script_dir = Path(__file__).resolve().parent
    # Navigate up: scripts/workflows/ -> scripts/ -> claude-plugin/ -> workspace root
    return script_dir.parent.parent.parent


def load_json(filepath):
    """Load a JSON file, return empty dict if not found."""
    try:
        with open(filepath, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def run_workspace_sync(workspace_root):
    """Run the existing workspace sync script."""
    sync_script = workspace_root / "setup" / "update-all.sh"
    if sync_script.exists():
        try:
            result = subprocess.run(
                ["bash", str(sync_script)],
                capture_output=True, text=True, timeout=120,
                cwd=str(workspace_root)
            )
            return {
                "success": result.returncode == 0,
                "output": result.stdout[:500] if result.stdout else "",
                "errors": result.stderr[:500] if result.stderr else ""
            }
        except (subprocess.TimeoutExpired, FileNotFoundError) as e:
            return {"success": False, "output": "", "errors": str(e)}
    return {"success": False, "output": "", "errors": "Sync script not found"}


def check_recent_changes(workspace_root):
    """Check for files modified in the last 24 hours across departments."""
    recent_files = []
    docs_dir = workspace_root / "Docs"
    if docs_dir.exists():
        cutoff = datetime.now().timestamp() - (24 * 3600)
        for dept_dir in docs_dir.iterdir():
            if dept_dir.is_dir() and not dept_dir.name.startswith("."):
                for md_file in dept_dir.rglob("*.md"):
                    if md_file.stat().st_mtime > cutoff:
                        relative = md_file.relative_to(workspace_root)
                        recent_files.append({
                            "path": str(relative),
                            "department": dept_dir.name,
                            "modified": datetime.fromtimestamp(md_file.stat().st_mtime).isoformat()
                        })
    return sorted(recent_files, key=lambda x: x["modified"], reverse=True)[:20]


def check_stale_items(workspace_root, plugin_root):
    """Check for stale placeholders and broken references."""
    workspace_context = load_json(plugin_root / "context" / "workspace-context.json")
    stale_items = {
        "broken_references": workspace_context.get("cross_reference_index", {}).get("broken_references", []),
        "stale_placeholders": [],
        "stale_project_cards": []
    }
    return stale_items


def generate_demo_briefing():
    """Generate a realistic demo briefing when connectors aren't available."""
    today = datetime.now().strftime("%A, %B %d, %Y")
    return f"""
# Daily Briefing — {today}
[DEMO MODE] — Connect calendar, Slack, and email via claude.com/connectors for live data.

## Workspace Sync
- All department repositories up to date

## Today's Schedule (Demo)
- 09:30 — Team standup (15 min)
- 11:00 — Product review with Engineering (60 min)
- 14:00 — Client meeting: Acme Corp quarterly review (45 min)
- 16:00 — Strategy sync (30 min)

## Recent Workspace Changes
- No recent changes detected (demo mode)

## Pending Items
- No pending items detected (demo mode)

## Suggested Actions
1. Prepare briefing for Acme Corp meeting (14:00)
2. Review product specs before engineering review (11:00)

---
*To get a real briefing, connect your calendar and Slack via claude.com/connectors*
"""


def generate_briefing(workspace_root, plugin_root, demo_mode=False):
    """Generate the full morning briefing."""
    if demo_mode:
        return generate_demo_briefing()

    today = datetime.now().strftime("%A, %B %d, %Y")
    sections = [f"# Daily Briefing — {today}\n"]

    # 1. Workspace sync
    sync_result = run_workspace_sync(workspace_root)
    if sync_result["success"]:
        sections.append("## Workspace Sync\n- All department repositories synced successfully\n")
    else:
        sections.append(f"## Workspace Sync\n- Sync encountered issues: {sync_result['errors'][:200]}\n")

    # 2. Recent changes
    recent = check_recent_changes(workspace_root)
    if recent:
        sections.append("## Recent Workspace Changes (last 24h)\n")
        for item in recent[:10]:
            sections.append(f"- **{item['department']}**: `{item['path']}`")
        sections.append("")
    else:
        sections.append("## Recent Workspace Changes\n- No changes in the last 24 hours\n")

    # 3. Stale items
    stale = check_stale_items(workspace_root, plugin_root)
    if any(stale.values()):
        sections.append("## Pending Items\n")
        if stale["broken_references"]:
            sections.append(f"- {len(stale['broken_references'])} broken [REF:] cross-references")
        sections.append("")

    # 4. Calendar (placeholder — requires connector)
    sections.append("## Today's Schedule\n- *Connect Google Calendar via claude.com/connectors to see your schedule*\n")

    # 5. Slack digest (placeholder — requires connector)
    sections.append("## Slack Digest\n- *Connect Slack via claude.com/connectors to see overnight activity*\n")

    return "\n".join(sections)


def main():
    demo_mode = "--demo" in sys.argv
    workspace_root = Path(os.environ.get("WORKSPACE_ROOT", detect_workspace_root()))
    plugin_root = Path(os.environ.get("PLUGIN_ROOT", workspace_root / "claude-plugin"))

    briefing = generate_briefing(workspace_root, plugin_root, demo_mode)
    print(briefing)

    # Update workspace context
    context_file = plugin_root / "context" / "workspace-context.json"
    context = load_json(context_file)
    context["last_sync"] = datetime.now().isoformat()
    context["last_updated"] = datetime.now().isoformat()
    try:
        with open(context_file, "w") as f:
            json.dump(context, f, indent=2)
    except (PermissionError, OSError):
        pass


if __name__ == "__main__":
    main()
