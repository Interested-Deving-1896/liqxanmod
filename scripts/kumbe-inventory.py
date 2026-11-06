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
        return result.stdout.strip()
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
        top = git_value(source, "rev-parse", "--show-toplevel")
        head = git_value(source, "rev-parse", "HEAD") if top and Path(top).resolve() == source.resolve() else None
        if head:
            shallow = git_value(source, "rev-parse", "--is-shallow-repository")
            status = git_value(source, "status", "--porcelain", "--untracked-files=all")
            item["git"] = {
                "commit": head,
                "branch": git_value(source, "branch", "--show-current"),
                "remote": git_value(source, "remote", "get-url", "origin"),
                "commit_timestamp": git_value(source, "show", "-s", "--format=%cI", "HEAD"),
                "object_format": git_value(source, "rev-parse", "--show-object-format"),
                "is_shallow": shallow == "true" if shallow is not None else None,
                "working_tree_clean": status == "" if status is not None else None,
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



def normalize_git_remote(remote: str | None) -> str | None:
    if not remote:
        return None
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://", remote):
        return remote
    match = re.fullmatch(r"git@([^:]+):(.+)", remote)
    if match:
        return f"ssh://git@{match.group(1)}/{match.group(2)}"
    return None


def git_source_input(path: Path, input_id: str, role: str,
                     kernel_version_value: str | None = None) -> dict | None:
    top = git_value(path, "rev-parse", "--show-toplevel")
    if not top or Path(top).resolve() != path.resolve():
        return None
    commit = git_value(path, "rev-parse", "HEAD")
    remote = normalize_git_remote(git_value(path, "remote", "get-url", "origin"))
    if not commit or not re.fullmatch(r"(?:[a-fA-F0-9]{40}|[a-fA-F0-9]{64})", commit) or not remote:
        return None
    branch = git_value(path, "branch", "--show-current")
    clean_url = re.sub(r"\.git$", "", remote)
    repository = "/".join(clean_url.rstrip("/").split("/")[-2:])
    return {
        "input_id": input_id,
        "role": role,
        "kind": "git",
        "repository": repository,
        "url": remote,
        "ref": branch or "HEAD",
        "commit": commit,
        "kernel_version": kernel_version_value,
        "integrity": "unverified",
        "notes": [
            "Commit identity was read from the local checkout.",
            "The adapter did not fetch the remote or independently verify that the remote advertises this object."
        ]
    }


def source_input_inventory(root: Path, sources: list[dict], patch_sets: list[dict],
                           configs: list[dict], warnings: list[str]) -> list[dict]:
    inputs = []
    kernel_index = 0
    for candidate in sources:
        path = root / candidate["path"]
        record = git_source_input(
            path, f"kernel-source-{kernel_index + 1}", "kernel-source",
            candidate.get("kernel_version")
        )
        if record:
            inputs.append(record)
            kernel_index += 1
    if patch_sets:
        record = git_source_input(root, "provider-patches", "provider-patches")
        if record:
            inputs.append(record)
        else:
            warnings.append("Patch queue files were inventoried locally, but no immutable provider-repository Git identity with an origin URL was available.")
    if configs:
        record = git_source_input(root, "config-bundle", "config-bundle")
        if record:
            inputs.append(record)
        else:
            warnings.append("Configuration files were inventoried locally, but no immutable provider-repository Git identity with an origin URL was available.")
    if not any(item["role"] == "kernel-source" for item in inputs):
        warnings.append("No independently identified kernel-source Git input was emitted; archive inputs require an exact archive version and SHA-256 before they can be represented in manifest v1.1.")
    return inputs


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
        "inventory_schema_version": "1.1.0",
        "provider": PROVIDER,
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "read_only": True,
        "source_candidates": source_inventory(root, warnings),
        "patch_sets": patch_inventory(root, warnings),
        "config_inputs": config_inventory(root),
        "source_inputs": [],
        "warnings": warnings,
        "limitations": [
            "No network requests, source fetches, patch application, builds, or writes are performed.",
            "A listed patch hash proves only local file identity, not applicability or correctness.",
            "A local branch/ref is not a substitute for an immutable source commit.",
            "This inventory is evidence input, not a validated migration manifest."
        ],
    }
    result["source_inputs"] = source_input_inventory(
        root, result["source_candidates"], result["patch_sets"],
        result["config_inputs"], warnings
    )
    result["warnings"] = warnings
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
