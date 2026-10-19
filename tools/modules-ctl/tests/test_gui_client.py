import json
import unittest
from pathlib import Path

from modules_ctl.gui.client import CliClient, CliCommandError
from modules_ctl.gui.model import ModuleCommand
from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus
from tests.fakes import ScriptedRunner

NIXOS = ModuleKind.NIXOS


class QueryTest(unittest.TestCase):
    def test_hosts_come_from_the_hosts_command(self) -> None:
        runner = ScriptedRunner({"hosts --json": (0, '["box", "laptop"]', "")})
        self.assertEqual(CliClient(run_command=runner).hosts(), ["box", "laptop"])

    def test_statuses_are_parsed_for_the_chosen_host(self) -> None:
        records = [{"kind": "nixos", "name": "a", "state": "new"}]
        runner = ScriptedRunner({"--host box status --json": (0, json.dumps(records), "")})
        self.assertEqual(
            CliClient(run_command=runner).statuses("box"),
            [ModuleStatus(NIXOS, "a", ModuleState.NEW)],
        )

    def test_the_repo_flag_is_forwarded_only_when_given(self) -> None:
        runner = ScriptedRunner({"--repo /r --host box status --json": (0, "[]", "")})
        CliClient(Path("/r"), runner).statuses("box")
        self.assertEqual(runner.invocations, ["--repo /r --host box status --json"])

    def test_errors_surface_the_cli_message(self) -> None:
        runner = ScriptedRunner({"--host box status --json": (1, "", "modules-ctl: nix broke\n")})
        with self.assertRaises(CliCommandError) as raised:
            CliClient(run_command=runner).statuses("box")
        self.assertEqual(str(raised.exception), "nix broke")

    def test_an_error_with_no_message_still_says_something(self) -> None:
        runner = ScriptedRunner({"--host box status --json": (3, "", "")})
        with self.assertRaisesRegex(CliCommandError, "status 3"):
            CliClient(run_command=runner).statuses("box")

    def test_unreadable_output_is_reported_not_raised_raw(self) -> None:
        for output in ("not json", '[{"kind": "bogus", "name": "a", "state": "new"}]', '[{"name": "a"}]'):
            with self.subTest(output):
                runner = ScriptedRunner({"--host box status --json": (0, output, "")})
                with self.assertRaises(CliCommandError):
                    CliClient(run_command=runner).statuses("box")


class ApplyTest(unittest.TestCase):
    commands = [
        ModuleCommand.enable(NIXOS, "a"),
        ModuleCommand.disable(NIXOS, "b"),
        ModuleCommand.prune(),
    ]

    def test_sends_each_command_in_order(self) -> None:
        runner = ScriptedRunner()
        outcome = CliClient(run_command=runner).apply("box", self.commands)
        self.assertTrue(outcome.succeeded)
        self.assertEqual(
            runner.invocations,
            ["--host box enable nixos a", "--host box disable nixos b", "--host box prune"],
        )

    def test_stops_at_the_first_failure_and_reports_progress(self) -> None:
        runner = ScriptedRunner({"--host box disable nixos b": (1, "", "no such module")})
        outcome = CliClient(run_command=runner).apply("box", self.commands)
        self.assertFalse(outcome.succeeded)
        self.assertEqual(outcome.applied, (self.commands[0],))
        self.assertEqual(outcome.failure, "no such module")
        self.assertEqual(len(runner.invocations), 2)


class InvocationTest(unittest.TestCase):
    def test_builds_the_full_argv_with_global_flags_before_the_command(self) -> None:
        argv = CliClient(Path("/r")).invocation("box", ModuleCommand.rebuild())
        self.assertEqual(argv[-5:], ["--repo", "/r", "--host", "box", "rebuild"])
        self.assertEqual(argv[1:3], ["-m", "modules_ctl"])


class PreviewTest(unittest.TestCase):
    def test_shows_the_command_as_typed_and_quotes_awkward_names(self) -> None:
        client = CliClient()
        self.assertEqual(
            client.preview("box", ModuleCommand.enable(NIXOS, "vpn-gui")),
            "modules-ctl --host box enable nixos vpn-gui",
        )
        self.assertIn("'my module'", client.preview("box", ModuleCommand.enable(NIXOS, "my module")))


if __name__ == "__main__":
    unittest.main()
