#!/usr/bin/env python3
"""Focused, read-only invariants for the liqxanmod Ageless compatibility profile."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
profile = json.loads((ROOT / "integrations/ageless-linux-compatibility.json").read_text())
doc = ROOT / "integrations/ageless-linux-kernel-compatibility.md"
audit = ROOT / "integrations/ageless-linux-upstream-audit.md"

assert profile["profile"] == "ageless-linux"
assert profile["provider"] == "liqxanmod"
assert profile["integration_kind"] == "base-os-compatibility-metadata"
assert profile["support_status"] == "inventory-only"
assert profile["compatibility_status"] == "unknown"
assert profile["ageless_source"]["commit"] == "1e1b00f45d494a41412403e9e909b0cc737bc2ae"
assert re.fullmatch(r"[0-9a-f]{40}", profile["ageless_source"]["tree"])
assert profile["ageless_source"]["commit_signature"] == "unsigned"
assert profile["ageless_source"]["integrity"] == "content-addressed-but-not-authenticated"
assert profile["base_os"]["converted_id_is_authoritative"] is False
required = {"distribution_id", "release", "architecture", "package_manager", "init_system"}
assert required.issubset(set(profile["base_os"]["required_fields"]))
for key in ("execute_conversion", "execute_upstream_tests_on_runner", "patch_apply", "build", "install", "publish"):
    assert profile["safety"][key] is False, key
assert profile["safety"]["isolated_test_environment_required"] is True
assert {"base-image-digest", "architecture", "kernel-provider-source-identity", "isolated-test-report"}.issubset(set(profile["evidence_required"]))
assert doc.is_file() and audit.is_file()
if provider == "liquorix":
    assert profile["provider_constraints"]["preserve_vanilla_archive_provenance"] is True
    assert profile["provider_constraints"]["preserve_liquorix_package_provenance"] is True
    assert profile["provider_constraints"]["signature_verification_required"] is True
elif provider == "xanmod":
    assert profile["provider_constraints"]["lanes"] == ["MAIN", "EDGE", "LTS", "RT"]
    assert profile["provider_constraints"]["lane_identity_must_remain_distinct"] is True
elif provider == "liqxanmod":
    assert profile["provider_constraints"]["kernel_lane_must_be_resolved_from_provider_manifest"] is True
print("liqxanmod Ageless compatibility invariants: PASS")
