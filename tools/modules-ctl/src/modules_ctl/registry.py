"""Asking the flake which modules it registers."""

import json
import subprocess
from collections.abc import Callable
from pathlib import Path
from typing import Protocol

from modules_ctl.errors import RegistryError
from modules_ctl.model import ModuleKind

CommandRunner = Callable[..., subprocess.CompletedProcess[str]]


class ModuleRegistry(Protocol):
    def registered(self, kind: ModuleKind) -> frozenset[str]:
        """Names registered as `flake.modules.<kind>.<name>`."""
        ...


class NixModuleRegistry:
    """Reads registered module names with `nix eval`.

    `builtins.attrNames` does not force the module values, so this stays cheap.
    """

    def __init__(self, flake_dir: Path, run_command: CommandRunner = subprocess.run) -> None:
        self._flake_dir = flake_dir
        self._run_command = run_command

    def registered(self, kind: ModuleKind) -> frozenset[str]:
        completed = _run(
            self._run_command,
            [
                "nix", "eval", f"{self._flake_dir}#modules.{kind.value}",
                "--apply", "builtins.attrNames", "--json",
            ],
        )
        if completed.returncode != 0:
            raise RegistryError(
                f"`nix eval` failed for {kind.value} modules:\n{completed.stderr.strip()}"
            )
        return frozenset(json.loads(completed.stdout))


def expose_new_module_files_to_flake(
    repo: Path, run_command: CommandRunner = subprocess.run
) -> None:
    """Make freshly created module files visible to flake evaluation.

    Flakes only see git-tracked files. Intent-to-add tracks a new file without
    staging its content, so a module is discoverable the moment it is created.
    """
    if not (repo / ".git").exists():
        return
    completed = _run(
        run_command, ["git", "-C", str(repo), "add", "--intent-to-add", "--", "modules"]
    )
    if completed.returncode != 0:
        raise RegistryError(f"`git add --intent-to-add` failed:\n{completed.stderr.strip()}")


def _run(run_command: CommandRunner, command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return run_command(command, capture_output=True, text=True, check=False)
    except FileNotFoundError as error:
        raise RegistryError(f"`{command[0]}` is not installed or not on PATH") from error
