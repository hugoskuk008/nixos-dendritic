import tempfile
import unittest
from pathlib import Path

from modules_ctl.errors import HostNotFoundError, RepoNotFoundError
from modules_ctl.repository import host_directory, list_hosts, locate_repository


class LocateRepositoryTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.elsewhere = self.root / "elsewhere"
        self.elsewhere.mkdir()

    def make_flake(self, path: Path) -> Path:
        path.mkdir(parents=True, exist_ok=True)
        (path / "flake.nix").write_text("")
        return path

    def test_walks_up_from_a_nested_directory(self) -> None:
        flake = self.make_flake(self.root / "repo")
        nested = flake / "tools" / "modules-ctl" / "src"
        nested.mkdir(parents=True)
        self.assertEqual(locate_repository(nested, fallback=self.root / "unused"), flake)

    def test_falls_back_when_started_outside_any_flake(self) -> None:
        fallback = self.make_flake(self.root / "home" / "nixos-dendritic")
        self.assertEqual(locate_repository(self.elsewhere, fallback), fallback)

    def test_nearest_flake_beats_the_fallback(self) -> None:
        nearby = self.make_flake(self.root / "checkout")
        fallback = self.make_flake(self.root / "home" / "nixos-dendritic")
        self.assertEqual(locate_repository(nearby, fallback), nearby)

    def test_fails_naming_every_place_it_looked(self) -> None:
        with self.assertRaisesRegex(RepoNotFoundError, "pass --repo"):
            locate_repository(self.elsewhere, fallback=self.root / "missing")


class HostsTest(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.repo = Path(directory.name)

    def test_lists_only_directories_alphabetically(self) -> None:
        for name in ("laptop", "desktop"):
            (self.repo / "hosts" / name).mkdir(parents=True)
        (self.repo / "hosts" / "mk-host.nix").write_text("")
        self.assertEqual(list_hosts(self.repo), ["desktop", "laptop"])

    def test_no_hosts_directory_means_no_hosts(self) -> None:
        self.assertEqual(list_hosts(self.repo), [])

    def test_unknown_host_error_lists_the_available_ones(self) -> None:
        (self.repo / "hosts" / "box").mkdir(parents=True)
        with self.assertRaisesRegex(HostNotFoundError, "'nope'.*available: box"):
            host_directory(self.repo, "nope")

    def test_known_host_resolves_to_its_directory(self) -> None:
        (self.repo / "hosts" / "box").mkdir(parents=True)
        self.assertEqual(host_directory(self.repo, "box"), self.repo / "hosts" / "box")


if __name__ == "__main__":
    unittest.main()
