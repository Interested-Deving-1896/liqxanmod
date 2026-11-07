#!/usr/bin/env python3
"""Consume a BDFS Ageless compatibility report without enabling kernel actions."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

PROVIDER = "liqxanmod"


def consume(report: dict[str, Any]) -> dict[str, Any]:
    if report.get("schema_version") != 1 or report.get("profile") != "bdfs.ageless-provider-compatibility-report":
        raise ValueError("unsupported BDFS compatibility report schema/profile")
    if report.get("compatibility_status") != "unknown":
        raise ValueError("this adapter accepts only conservative unknown-status reports")
    if report.get("safety", {}).get("read_only") is not True:
        raise ValueError("BDFS report is not marked read-only")
    providers = report.get("reports")
    if not isinstance(providers, dict) or PROVIDER not in providers:
        raise ValueError(f"BDFS report does not contain provider {PROVIDER}")
    selected = providers[PROVIDER]
    if selected.get("provider_profile") != PROVIDER:
        raise ValueError("provider identity mismatch")
    if selected.get("compatibility_status") != "unknown":
        raise ValueError("provider compatibility must remain unknown")
    actions = selected.get("actions", {})
    if any(actions.get(key) is not False for key in ("conversion", "patch_apply", "build", "install", "publish")):
        raise ValueError("BDFS report unexpectedly enables a protected action")
    return {
        "schema_version": 1,
        "profile": "liqxanmod.ageless-compatibility-consumption",
        "provider": PROVIDER,
        "compatibility_status": "unknown",
        "support_status": "inventory-only",
        "bdfs_inventory_complete": selected.get("inventory_complete") is True,
        "missing_required_inventory_fields": selected.get("missing_required_inventory_fields", []),
        "base_os": selected.get("base_os", {}),
        "architecture": selected.get("architecture"),
        "kernel": selected.get("kernel", {}),
        "provider_constraints": selected.get("provider_constraints", {}),
        "decision": selected.get("decision", "compatibility evidence is not established"),
        "actions": {"patch_apply": False, "build": False, "install": False, "publish": False},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True, type=Path, help="BDFS compatibility report JSON")
    parser.add_argument("--output", type=Path, help="write provider decision to this path; stdout otherwise")
    args = parser.parse_args()
    result = json.dumps(consume(json.loads(args.report.read_text(encoding="utf-8"))), indent=2, sort_keys=True) + "\\n"
    if args.output:
        args.output.write_text(result, encoding="utf-8")
    else:
        print(result, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
