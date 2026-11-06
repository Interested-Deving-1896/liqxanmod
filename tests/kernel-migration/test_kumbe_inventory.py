#!/usr/bin/env python3
"""Tests for the provider's read-only KUMBE inventory command."""
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "kumbe-inventory.py"
PROVIDER = "liqxanmod"
SOURCE_PATH = "kernel/src"
PATCH_PATH = "patches"


class InventoryTests(unittest.TestCase):
    def run_inventory(self, root):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--root", str(root)],
            check=True, capture_output=True, text=True,
        )
        return json.loads(result.stdout)

    def test_inventory_is_read_only_and_reports_local_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / SOURCE_PATH
            source.mkdir(parents=True)
            (source / "Makefile").write_text(
                "VERSION = 6\nPATCHLEVEL = 12\nSUBLEVEL = 4\nEXTRAVERSION =\n",
                encoding="utf-8",
            )

            patch_root = root / PATCH_PATH
            patch_root.mkdir(parents=True)
            patch = patch_root / "0001-example.patch"
            patch.write_text("diff --git a/example b/example\n", encoding="utf-8")
            (patch_root / "series").write_text("0001-example.patch\n", encoding="utf-8")

            before = sorted(str(path.relative_to(root)) for path in root.rglob("*"))
            data = self.run_inventory(root)
            after = sorted(str(path.relative_to(root)) for path in root.rglob("*"))

            self.assertEqual(before, after, "inventory command must not create or modify files")
            self.assertEqual(data["provider"], PROVIDER)
            self.assertTrue(data["read_only"])
            self.assertEqual(data["source_candidates"][0]["kernel_version"], "6.12.4")
            entry = data["patch_sets"][0]["entries"][0]
            self.assertTrue(entry["present"])
            self.assertEqual(entry["sha256"], hashlib.sha256(patch.read_bytes()).hexdigest())

    def test_quilt_options_and_path_traversal_are_handled_safely(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            patch_root = root / PATCH_PATH
            patch_root.mkdir(parents=True)
            (patch_root / "0001-example.patch").write_text("patch\\n", encoding="utf-8")
            (patch_root / "series").write_text("0001-example.patch -p1 -R\\n../outside.patch -p2\\n", encoding="utf-8")
            data = self.run_inventory(root)
            entries = data["patch_sets"][0]["entries"]
            self.assertEqual(entries[0]["options"], ["-p1", "-R"])
            self.assertTrue(entries[0]["present"])
            self.assertTrue(entries[1]["unsafe_path"])
            self.assertFalse(entries[1]["present"])
            self.assertTrue(any("outside patch root" in warning for warning in data["warnings"]))

    def test_missing_patch_is_reported_not_accepted(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            patch_root = root / PATCH_PATH
            patch_root.mkdir(parents=True)
            (patch_root / "series").write_text("missing.patch\n", encoding="utf-8")
            data = self.run_inventory(root)
            self.assertFalse(data["patch_sets"][0]["entries"][0]["present"])
            self.assertTrue(any("Missing patch" in warning for warning in data["warnings"]))


if __name__ == "__main__":
    unittest.main()
