import io
import subprocess
import unittest
from pathlib import Path

from modules_ctl.errors import RebuildRefusedError
from modules_ctl.rebuild import Machine, rebuild_command, run_rebuild, targets_machine

REPO = Path("/home/u/nixos-dendritic")


class RebuildCommandTest(unittest.TestCase):
    def test_prefers_nh_with_the_repo_and_host_spelled_out(self) -> None:
        self.assertEqual(
            rebuild_command(REPO, "box", has_nh=True),
            ["nh", "os", "switch", str(REPO), "--hostname", "box"],
        )

    def test_falls_back_to_nixos_rebuild_through_sudo(self) -> None:
        self.assertEqual(
            rebuild_command(REPO, "box", has_nh=False),
            ["sudo", "nixos-rebuild", "switch", "--flake", f"{REPO}#box"],
        )


class RunRebuildTest(unittest.TestCase):
    def machine(self, hostname: str = "box", returncode: int = 0) -> tuple[Machine, list[list[str]]]:
        sent: list[list[str]] = []

        def run_command(command: list[str], **_: object) -> subprocess.CompletedProcess[str]:
            sent.append(command)
            return subprocess.CompletedProcess(command, returncode)

        return Machine(hostname, has_nh=True, run_command=run_command), sent

    def test_runs_the_command_after_echoing_it(self) -> None:
        machine, sent = self.machine()
        out = io.StringIO()
        self.assertEqual(run_rebuild(REPO, "box", machine, out), 0)
        self.assertEqual(sent, [rebuild_command(REPO, "box", has_nh=True)])
        self.assertTrue(out.getvalue().startswith("$ nh os switch"))

    def test_returns_the_rebuilds_own_exit_status(self) -> None:
        machine, _ = self.machine(returncode=4)
        self.assertEqual(run_rebuild(REPO, "box", machine, io.StringIO()), 4)

    def test_refuses_another_hosts_configuration_without_running_anything(self) -> None:
        machine, sent = self.machine(hostname="desktop")
        with self.assertRaisesRegex(RebuildRefusedError, "'laptop' is not this machine"):
            run_rebuild(REPO, "laptop", machine, io.StringIO())
        self.assertEqual(sent, [])

    def test_force_allows_another_host(self) -> None:
        machine, sent = self.machine(hostname="desktop")
        run_rebuild(REPO, "laptop", machine, io.StringIO(), force=True)
        self.assertEqual(len(sent), 1)

    def test_a_host_targets_the_machine_of_the_same_name_only(self) -> None:
        self.assertTrue(targets_machine("box", "box"))
        self.assertFalse(targets_machine("laptop", "Laptroll"))


if __name__ == "__main__":
    unittest.main()
