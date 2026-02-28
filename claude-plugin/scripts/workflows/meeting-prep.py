#!/usr/bin/env python3
"""
Meeting Preparation Workflow

Auto-prepares context for upcoming meetings by gathering attendee information,
previous meeting history, project status, and relevant documents.

Connectors used: calendar, filesystem, notion, slack

Usage:
    python3 claude-plugin/scripts/workflows/meeting-prep.py [--meeting-id ID] [--demo]

Environment Variables:
    WORKSPACE_ROOT - Path to workspace root (default: auto-detect)
    PLUGIN_ROOT    - Path to plugin directory (default: auto-detect)
"""

import json
import os
import sys
from datetime import datetime
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


def search_workspace_for_attendee(workspace_root, attendee_name):
    """Search workspace files for mentions of an attendee."""
    mentions = []
    search_dirs = [
        workspace_root / "Docs" / "SalesAndMarketing" / "Client-Meetings-Analysis",
        workspace_root / "Projects",
        workspace_root / "Docs" / "SalesAndMarketing",
    ]
    for search_dir in search_dirs:
        if search_dir.exists():
            for md_file in search_dir.rglob("*.md"):
                try:
                    content = md_file.read_text(encoding="utf-8", errors="ignore")
                    if attendee_name.lower() in content.lower():
                        relative = md_file.relative_to(workspace_root)
                        mentions.append(str(relative))
                except (PermissionError, OSError):
                    continue
    return mentions[:10]


def generate_demo_prep():
    """Generate a realistic demo meeting preparation."""
    return """
# Meeting Preparation
[DEMO MODE] — Connect calendar via claude.com/connectors for live meeting data.

## Meeting: Quarterly Business Review
- **Time**: Today, 14:00 (45 min)
- **Attendees**: Sarah Chen (VP Product, Acme Corp), Mike Torres (Account Manager)
- **Location**: Zoom

## Attendee Context (Demo)

### Sarah Chen — VP Product, Acme Corp
- **Previous meetings**: 3 meetings in last quarter
- **Key topics**: Product roadmap alignment, API integration, pricing discussion
- **Last interaction**: January 15, 2026 — discussed Q1 priorities
- **Sentiment**: Positive, actively expanding usage

### Mike Torres — Account Manager (Internal)
- **Role**: Primary account contact for Acme Corp
- **Recent notes**: Flagged potential upsell opportunity

## Relevant Documents (Demo)
- `Docs/SalesAndMarketing/Client-Meetings-Analysis/AI-Projects-Review-Analysis.md`
- `Projects/Status-Projects/acme-corp-status.md`

## Suggested Talking Points
1. Q1 results and ROI metrics
2. Product roadmap preview for Q2
3. API integration timeline update
4. Expansion discussion — additional team licenses

## Questions to Ask
1. How is the team adoption going since the Q1 rollout?
2. What are your top priorities for Q2?
3. Any blockers or concerns we should address?

---
*Connect your calendar via claude.com/connectors for real meeting prep*
"""


def generate_prep(workspace_root, meeting_id=None, demo_mode=False):
    """Generate meeting preparation document."""
    if demo_mode:
        return generate_demo_prep()

    sections = ["# Meeting Preparation\n"]
    sections.append("*Calendar connector not configured. Provide meeting details manually.*\n")
    sections.append("## How to use this skill:\n")
    sections.append("1. Connect Google Calendar via claude.com/connectors")
    sections.append("2. Ask Claude: \"Prepare me for my next meeting\"")
    sections.append("3. Claude will automatically pull attendee context and relevant documents\n")
    sections.append("## Manual prep available:\n")
    sections.append("Tell Claude the meeting details and attendees, and it will search the workspace for relevant context.\n")

    return "\n".join(sections)


def main():
    demo_mode = "--demo" in sys.argv
    meeting_id = None
    for i, arg in enumerate(sys.argv):
        if arg == "--meeting-id" and i + 1 < len(sys.argv):
            meeting_id = sys.argv[i + 1]

    workspace_root = Path(os.environ.get("WORKSPACE_ROOT", detect_workspace_root()))

    prep = generate_prep(workspace_root, meeting_id, demo_mode)
    print(prep)


if __name__ == "__main__":
    main()
