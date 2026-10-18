import tempfile
import unittest
from pathlib import Path

from modules_ctl.errors import RegistryError
from modules_ctl.model import ModuleKind
from modules_ctl.registry import NixModuleRegistry, expose_new_module_files_to_flake
from tests.fakes import RecordingRunner


class NixModuleRegistryTest(unittest.TestCase):
    def test_parses_attribute_names_from_nix_eval(self) -> None:
        runner = RecordingRunner(stdout='["system", "locale"]')
        registry = NixModuleRegistry(Path("/repo"), runner)
        self.assertEqual(registry.registered(ModuleKind.HOME_MANAGER), frozenset({"system", "locale"}))
        self.assertIn("/repo#modules.homeManager", runner.commands[0])

    def test_nix_failure_surfaces_its_stderr(self) -> None:
        registry = NixModuleRegistry(Path("/repo"), RecordingRunner(returncode=1, stderr="boom\n"))
        with self.assertRaisesRegex(RegistryError, "(?s)nixos.*boom"):
            registry.registered(ModuleKind.NIXOS)

    def test_missing_nix_executable_is_reported(self) -> None:
        def no_such_program(*_: object, **__: object):
            raise FileNotFoundError

        with self.assertRaisesRegex(RegistryError, "`nix` is not installed"):
            NixModuleRegistry(Path("/repo"), no_such_program).registered(ModuleKind.NIXOS)


class ExposeNewModuleFilesTest(unittest.TestCase):
    def test_skips_directories_that_are_not_git_repositories(self) -> None:
        runner = RecordingRunner()
        with tempfile.TemporaryDirectory() as plain_directory:
            expose_new_module_files_to_flake(Path(plain_directory), runner)
        self.assertEqual(runner.commands, [])

    def test_marks_module_files_intent_to_add(self) -> None:
        runner = RecordingRunner()
        with tempfile.TemporaryDirectory() as repo:
            (Path(repo) / ".git").mkdir()
            expose_new_module_files_to_flake(Path(repo), runner)
        self.assertEqual(runner.commands[0][3:], ["add", "--intent-to-add", "--", "modules"])


if __name__ == "__main__":
    unittest.main()
