#!/usr/bin/env python3
"""Regression tests for the GLITCH app SDK using only Python's standard library."""

import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

SDK = Path(__file__).with_name("glitch.py")
EXAMPLE = Path(__file__).resolve().parents[2] / "examples" / "apps" / "hello-world"


class SDKTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(
            [sys.executable, str(SDK), *map(str, args)],
            text=True, capture_output=True, check=False,
        )

    def test_example_validates(self):
        result = self.run_cli("validate", EXAMPLE)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Hello GLITCH", result.stdout)

    def test_package_round_trip(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary) / "hello.gcpkg"
            packed = self.run_cli("pack", EXAMPLE, "--output", package)
            self.assertEqual(packed.returncode, 0, packed.stderr)
            inspected = self.run_cli("inspect", package)
            self.assertEqual(inspected.returncode, 0, inspected.stderr)
            with zipfile.ZipFile(package) as archive:
                self.assertEqual(set(archive.namelist()), {"glitch-app.json", "main.py"})

    def test_rejects_parent_traversal(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "glitch-app.json").write_text(json.dumps({
                "schema": 1, "id": "org.example.bad", "name": "Bad",
                "version": "1.0.0", "runtime": "python3",
                "entrypoint": "../outside.py", "files": ["../outside.py"],
            }), encoding="utf-8")
            (root.parent / "outside.py").write_text("print('no')", encoding="utf-8")
            result = self.run_cli("validate", root)
            self.assertEqual(result.returncode, 2)
            self.assertIn("unsafe path", result.stderr)

    def test_rejects_missing_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "glitch-app.json").write_text(json.dumps({
                "schema": 1, "id": "org.example.missing", "name": "Missing",
                "version": "1.0.0", "runtime": "python3",
                "entrypoint": "main.py", "files": ["main.py"],
            }), encoding="utf-8")
            result = self.run_cli("validate", root)
            self.assertEqual(result.returncode, 2)
            self.assertIn("missing or escaping", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
