"""Unit tests for the GUI's pure helpers (no display needed)."""

import json
import tempfile
import unittest
from pathlib import Path

from modules_ctl.gui import ModuleRow, list_hosts, parse_status, plan_changes


class ParseStatusTests(unittest.TestCase):
    def test_parses_cli_json_output(self):
        payload = json.dumps(
            [
                {"kind": "nixos", "name": "steam", "state": "enabled"},
                {"kind": "homeManager", "name": "zsh", "state": "new"},
            ]
        )
        rows = parse_status(payload)
        self.assertEqual(
            rows,
            [
                ModuleRow(kind="nixos", name="steam", current="enabled"),
                ModuleRow(kind="homeManager", name="zsh", current="new"),
            ],
        )


class PlanChangesTests(unittest.TestCase):
    def test_only_changed_rows_produce_operations(self):
        rows = [
            ModuleRow("nixos", "steam", "enabled", "disabled"),
            ModuleRow("nixos", "git", "enabled"),  # untouched
            ModuleRow("homeManager", "zsh", "new", "enabled"),
        ]
        self.assertEqual(
            plan_changes(rows),
            [("disable", "nixos", "steam"), ("enable", "homeManager", "zsh")],
        )

    def test_reverting_a_row_removes_its_operation(self):
        rows = [ModuleRow("nixos", "steam", "enabled", "enabled")]
        self.assertEqual(plan_changes(rows), [])

    def test_missing_modules_are_not_planned_by_helpers_caller(self):
        # plan_changes trusts the caller; the GUI skips 'missing' rows before setting desires.
        rows = [ModuleRow("nixos", "ghost", "missing")]
        self.assertEqual(plan_changes(rows), [])


class ListHostsTests(unittest.TestCase):
    def test_only_hosts_with_selection_file_are_listed(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / "hosts" / "alpha").mkdir(parents=True)
            (repo / "hosts" / "alpha" / "modules.json").write_text("{}")
            (repo / "hosts" / "beta").mkdir(parents=True)  # no modules.json
            (repo / "modules").mkdir()
            (repo / "not-a-host.txt").write_text("")
            self.assertEqual(list_hosts(repo), ["alpha"])

    def test_missing_hosts_directory_gives_no_hosts(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(list_hosts(Path(tmp)), [])


if __name__ == "__main__":
    unittest.main()
