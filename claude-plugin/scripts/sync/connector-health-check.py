#!/usr/bin/env python3
"""
Connector Health Check

Verifies the status of all configured connectors by checking authentication,
connectivity, and basic functionality.

Usage:
    python3 claude-plugin/scripts/sync/connector-health-check.py [--verbose]

Environment Variables:
    WORKSPACE_ROOT - Path to workspace root (default: auto-detect)
    PLUGIN_ROOT    - Path to plugin directory (default: auto-detect)
    NOTION_TOKEN   - Notion API token (for Notion connector check)
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


def check_filesystem(workspace_root):
    """Check filesystem access to workspace directories."""
    status = {"name": "File System", "status": "healthy", "details": []}
    critical_dirs = [
        ("Docs/Strategy", "Strategy department"),
        ("Docs/Product", "Product department"),
        ("Docs/SalesAndMarketing", "Sales & Marketing department"),
        ("Docs/Operations", "Operations department"),
        ("scripts", "Scripts directory"),
    ]
    for dir_path, description in critical_dirs:
        full_path = workspace_root / dir_path
        if full_path.exists():
            status["details"].append(f"{description}: accessible")
        else:
            status["details"].append(f"{description}: NOT FOUND at {dir_path}")
            status["status"] = "degraded"
    return status


def check_code_execution():
    """Check code execution capability."""
    status = {"name": "Code Execution", "status": "healthy", "details": []}
    # Check Python
    try:
        import subprocess
        result = subprocess.run(["python3", "--version"], capture_output=True, text=True, timeout=5)
        status["details"].append(f"Python: {result.stdout.strip()}")
    except (FileNotFoundError, subprocess.TimeoutExpired):
        status["details"].append("Python: NOT AVAILABLE")
        status["status"] = "degraded"
    return status


def check_existing_scripts(workspace_root):
    """Check that existing workspace scripts are accessible."""
    status = {"name": "Workspace Scripts", "status": "healthy", "details": []}
    scripts = [
        ("scripts/check_range.py", "Range validation (MANDATORY)"),
        ("setup/update-all.sh", "Workspace sync"),
    ]
    for script_path, description in scripts:
        full_path = workspace_root / script_path
        if full_path.exists():
            status["details"].append(f"{description}: available at {script_path}")
        else:
            status["details"].append(f"{description}: NOT FOUND at {script_path}")
            if "MANDATORY" in description:
                status["status"] = "critical"
            else:
                status["status"] = "degraded"
    return status


def check_notion():
    """Check Notion connector availability."""
    status = {"name": "Notion", "status": "not_configured", "details": []}
    token = os.environ.get("NOTION_TOKEN")
    if token:
        status["status"] = "configured"
        status["details"].append("NOTION_TOKEN is set")
        db_id = os.environ.get("NOTION_DATABASE_ID")
        if db_id:
            status["details"].append("NOTION_DATABASE_ID is set")
        else:
            status["details"].append("NOTION_DATABASE_ID not set (optional)")
    else:
        status["details"].append("NOTION_TOKEN not set — connect via claude.com/connectors or set env var")
    return status


def check_builtin_connector(name, display_name):
    """Check status of a built-in Claude connector (configured via claude.com/connectors)."""
    return {
        "name": display_name,
        "status": "check_via_claude",
        "details": [f"Configure via claude.com/connectors — status checked within Claude app"]
    }


def run_health_check(workspace_root, plugin_root, verbose=False):
    """Run full health check across all connectors."""
    connectors_config = load_json(plugin_root / "config" / "connectors.json")
    configured_connectors = connectors_config.get("connectors", {})

    results = []

    # Local checks
    results.append(check_filesystem(workspace_root))
    results.append(check_code_execution())
    results.append(check_existing_scripts(workspace_root))
    results.append(check_notion())

    # Built-in connector checks
    builtin_connectors = [
        ("google_drive", "Google Drive"),
        ("google_docs", "Google Docs"),
        ("google_sheets", "Google Sheets"),
        ("slack", "Slack"),
        ("github", "GitHub"),
        ("calendar", "Google Calendar"),
        ("email", "Gmail"),
        ("zapier", "Zapier"),
    ]
    for conn_id, display_name in builtin_connectors:
        conn_config = configured_connectors.get(conn_id, {})
        enabled = conn_config.get("enabled", False)
        result = check_builtin_connector(conn_id, display_name)
        result["enabled_in_config"] = enabled
        results.append(result)

    # Generate report
    print("# Connector Health Check")
    print(f"**Date**: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")

    healthy = sum(1 for r in results if r["status"] == "healthy")
    total = len(results)
    print(f"## Summary: {healthy}/{total} connectors fully healthy\n")

    print("| Connector | Status | Notes |")
    print("|---|---|---|")
    for r in results:
        status_icon = {
            "healthy": "OK",
            "configured": "OK",
            "degraded": "WARN",
            "critical": "CRITICAL",
            "not_configured": "NOT SET",
            "check_via_claude": "CHECK APP"
        }.get(r["status"], "?")

        enabled_note = ""
        if "enabled_in_config" in r:
            enabled_note = " (enabled)" if r["enabled_in_config"] else " (disabled in config)"

        notes = r["details"][0] if r["details"] else ""
        print(f"| {r['name']}{enabled_note} | {status_icon} | {notes} |")

    if verbose:
        print("\n## Detailed Results\n")
        for r in results:
            print(f"### {r['name']}")
            print(f"- Status: {r['status']}")
            for detail in r["details"]:
                print(f"- {detail}")
            print()


def main():
    verbose = "--verbose" in sys.argv
    workspace_root = Path(os.environ.get("WORKSPACE_ROOT", detect_workspace_root()))
    plugin_root = Path(os.environ.get("PLUGIN_ROOT", workspace_root / "claude-plugin"))

    run_health_check(workspace_root, plugin_root, verbose)


if __name__ == "__main__":
    main()
