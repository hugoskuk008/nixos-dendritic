import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path

from modules_ctl.cli import main
from tests.fakes import FakeRegistry


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.repo = Path(directory.name)
        (self.repo / "hosts" / "box").mkdir(parents=True)
        self.registry = FakeRegistry(nixos={"a", "b"}, home_manager={"z"})

    def run_cli(self, *arguments: str) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stderr(err):
            code = main(["--repo", str(self.repo), "--host", "box", *arguments], registry=self.registry, out=out)
        return code, out.getvalue(), err.getvalue()

    def test_every_module_starts_out_new(self) -> None:
        code, out, _ = self.run_cli("status")
        self.assertEqual(code, 0)
        self.assertEqual(out.count("new"), 3)

    def test_enable_and_disable_persist_and_show_in_json_status(self) -> None:
        self.assertEqual(self.run_cli("enable", "nixos", "a")[0], 0)
        self.assertEqual(self.run_cli("disable", "homeManager", "z")[0], 0)
        _, out, _ = self.run_cli("status", "--json")
        states = {(s["kind"], s["name"]): s["state"] for s in json.loads(out)}
        self.assertEqual(
            states,
            {("nixos", "a"): "enabled", ("nixos", "b"): "new", ("homeManager", "z"): "disabled"},
        )

    def test_unknown_module_fails_without_creating_the_file(self) -> None:
        code, _, err = self.run_cli("enable", "nixos", "typo")
        self.assertEqual(code, 1)
        self.assertIn("typo", err)
        self.assertFalse((self.repo / "hosts" / "box" / "modules.json").exists())

    def test_prune_reports_and_removes_missing_entries(self) -> None:
        (self.repo / "hosts" / "box" / "modules.json").write_text('{"nixos": {"enabled": ["a", "gone"]}}')
        code, out, _ = self.run_cli("prune")
        self.assertEqual((code, out), (0, "removed missing nixos module 'gone'\n"))
        self.assertNotIn("gone", self.run_cli("status")[1])

    def test_unknown_host_lists_the_available_ones(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with redirect_stderr(err):
            code = main(["--repo", str(self.repo), "--host", "nope", "status"], registry=self.registry, out=out)
        self.assertEqual(code, 1)
        self.assertIn("available: box", err.getvalue())

    def test_malformed_selection_file_is_reported_not_raised(self) -> None:
        (self.repo / "hosts" / "box" / "modules.json").write_text("{")
        code, _, err = self.run_cli("status")
        self.assertEqual(code, 1)
        self.assertIn("modules.json", err)


if __name__ == "__main__":
    unittest.main()
