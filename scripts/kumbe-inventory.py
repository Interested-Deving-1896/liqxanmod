#!/usr/bin/env python3
"""Read-only KUMBE provider inventory; never fetches or modifies kernel sources."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

PROVIDER = "liqxanmod"
SOURCE_PATTERNS = ["kernel/src"]
PATCH_PATTERNS = ["patches"]
CONFIG_PATTERNS = ["configs"]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_value(path: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(path), *args],
            check=True, capture_output=True, text=True, timeout=5,
        )
        return result.stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def kernel_version(source: Path) -> str | None:
    makefile = source / "Makefile"
    if not makefile.is_file():
        return None
    values: dict[str, str] = {}
    for line in makefile.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"^(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION)\s*=\s*(.*?)\s*$", line)
        if match:
            values[match.group(1)] = match.group(2)
    if "VERSION" not in values or "PATCHLEVEL" not in values:
        return None
    return ".".join(values.get(key, "0") for key in ("VERSION", "PATCHLEVEL", "SUBLEVEL")) + values.get("EXTRAVERSION", "")


def expand_patterns(root: Path, patterns: list[str]) -> list[Path]:
    found: set[Path] = set()
    for pattern in patterns:
        for path in root.glob(pattern):
            if path.is_dir():
                found.add(path)
    return sorted(found, key=lambda path: str(path))


def source_inventory(root: Path, warnings: list[str]) -> list[dict]:
    candidates = []
    for source in expand_patterns(root, SOURCE_PATTERNS):
        item = {
            "path": source.relative_to(root).as_posix(),
            "kernel_version": kernel_version(source),
            "git": None,
        }
        head = git_value(source, "rev-parse", "HEAD")
        if head:
            item["git"] = {
                "commit": head,
                "branch": git_value(source, "branch", "--show-current"),
                "remote": git_value(source, "remote", "get-url", "origin"),
                "is_shallow": (source / ".git" / "shallow").is_file(),
            }
        else:
            item["source_kind"] = "non-git-tree"
        candidates.append(item)
    if not candidates:
        warnings.append("No local kernel source tree found; inventory did not fetch or resolve upstream sources.")
    return candidates


def patch_inventory(root: Path, warnings: list[str]) -> list[dict]:
    results = []
    for patch_root in expand_patterns(root, PATCH_PATTERNS):
        patch_base = patch_root.resolve()
        series_files = sorted(patch_root.rglob("series"))
        entries = []
        if series_files:
            for series in series_files:
                for line_number, raw in enumerate(series.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                    try:
                        fields = __import__("shlex").split(raw, comments=True)
                    except ValueError as exc:
                        warnings.append(f"Invalid quilt series line {series}:{line_number}: {exc}")
                        continue
                    if not fields:
                        continue
                    name, options = fields[0], fields[1:]
                    candidate = (series.parent / name).resolve()
                    safe = candidate.is_relative_to(patch_base)
                    if not safe:
                        warnings.append(f"Rejected quilt series path outside patch root: {series}:{line_number}")
                        entries.append({
                            "series": series.relative_to(root).as_posix(),
                            "line": line_number,
                            "path": name,
                            "options": options,
                            "present": False,
                            "unsafe_path": True,
                            "sha256": None,
                        })
                        continue
                    exists = candidate.is_file()
                    entry = {
                        "series": series.relative_to(root).as_posix(),
                        "line": line_number,
                        "path": candidate.relative_to(root.resolve()).as_posix(),
                        "options": options,
                        "present": exists,
                        "unsafe_path": False,
                        "sha256": sha256_file(candidate) if exists else None,
                    }
                    if not exists:
                        warnings.append("Missing patch referenced by series: " + entry["path"])
                    entries.append(entry)
        else:
            for patch in sorted(patch_root.rglob("*.patch")):
                entries.append({
                    "series": None,
                    "line": None,
                    "path": patch.relative_to(root).as_posix(),
                    "options": [],
                    "present": True,
                    "unsafe_path": False,
                    "sha256": sha256_file(patch),
                })
        results.append({
            "root": patch_root.relative_to(root).as_posix(),
            "entries": entries,
        })
    if not results:
        warnings.append("No local patch directory found; upstream patch queues may be fetched or cached elsewhere.")
    return results


def config_inventory(root: Path) -> list[dict]:
    results = []
    for config_root in expand_patterns(root, CONFIG_PATTERNS):
        for path in sorted(config_root.rglob("*")):
            if not path.is_file():
                continue
            if path.name == "config" or path.suffix in {".config", ".conf"}:
                results.append({
                    "path": path.relative_to(root).as_posix(),
                    "sha256": sha256_file(path),
                })
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1],
                        help="repository root (defaults to the checkout containing this script)")
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        parser.error(f"repository root is not a directory: {root}")

    warnings: list[str] = []
    result = {
        "inventory_schema_version": "1.0.0",
        "provider": PROVIDER,
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "read_only": True,
        "source_candidates": source_inventory(root, warnings),
        "patch_sets": patch_inventory(root, warnings),
        "config_inputs": config_inventory(root),
        "warnings": warnings,
        "limitations": [
            "No network requests, source fetches, patch application, builds, or writes are performed.",
            "A listed patch hash proves only local file identity, not applicability or correctness.",
            "A local branch/ref is not a substitute for an immutable source commit.",
            "This inventory is evidence input, not a validated migration manifest."
        ],
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
