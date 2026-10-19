import unittest

from modules_ctl.gui.terminal import TerminalError, launch_in_terminal, terminal_invocation


def installed(*names: str):
    """A `which` that finds only the named programs, under /bin."""
    return lambda name: f"/bin/{name}" if name in names else None


class TerminalInvocationTest(unittest.TestCase):
    command = ["modules-ctl", "--host", "box", "rebuild"]

    def test_terminal_variable_wins_over_known_terminals(self) -> None:
        invocation = terminal_invocation(self.command, {"TERMINAL": "foot"}, installed("foot", "kitty"))
        self.assertEqual(invocation[0], "/bin/foot")

    def test_known_terminals_are_tried_in_order_when_the_variable_is_unset(self) -> None:
        self.assertEqual(terminal_invocation(self.command, {}, installed("xterm", "kitty"))[0], "/bin/kitty")

    def test_an_unusable_terminal_variable_falls_back_instead_of_failing(self) -> None:
        invocation = terminal_invocation(self.command, {"TERMINAL": "gone"}, installed("xterm"))
        self.assertEqual(invocation[:2], ["/bin/xterm", "-e"])

    def test_each_terminal_is_told_to_run_the_program_its_own_way(self) -> None:
        expected = {"kitty": [], "alacritty": ["-e"], "wezterm": ["start", "--"], "gnome-terminal": ["--"]}
        for name, run_arguments in expected.items():
            with self.subTest(name):
                invocation = terminal_invocation(self.command, {}, installed(name))
                self.assertEqual(invocation[1 : 1 + len(run_arguments)], run_arguments)
                self.assertEqual(invocation[1 + len(run_arguments)], "bash")

    def test_an_unknown_terminal_gets_the_conventional_dash_e(self) -> None:
        invocation = terminal_invocation(self.command, {"TERMINAL": "st"}, installed("st"))
        self.assertEqual(invocation[:3], ["/bin/st", "-e", "bash"])

    def test_the_command_is_quoted_and_the_window_is_held_open(self) -> None:
        script = terminal_invocation(["modules-ctl", "enable", "nixos", "my module"], {}, installed("kitty"))[-1]
        self.assertIn("modules-ctl enable nixos 'my module';", script)
        self.assertIn("read -r _", script)
        self.assertIn('exit "$status"', script)

    def test_no_terminal_at_all_is_an_actionable_error(self) -> None:
        with self.assertRaisesRegex(TerminalError, "set \\$TERMINAL"):
            terminal_invocation(self.command, {}, installed())


class LaunchInTerminalTest(unittest.TestCase):
    def test_spawns_detached_and_names_the_terminal(self) -> None:
        spawned = []
        name = launch_in_terminal(
            ["modules-ctl", "rebuild"], {}, installed("kitty"),
            spawn=lambda command, **options: spawned.append((command, options)),
        )
        self.assertEqual(name, "kitty")
        self.assertEqual(spawned[0][0][0], "/bin/kitty")
        self.assertTrue(spawned[0][1]["start_new_session"])

    def test_a_terminal_that_will_not_start_is_reported(self) -> None:
        def refuse(*_args, **_options):
            raise PermissionError("denied")

        with self.assertRaisesRegex(TerminalError, "could not start /bin/kitty: denied"):
            launch_in_terminal(["x"], {}, installed("kitty"), spawn=refuse)


if __name__ == "__main__":
    unittest.main()
