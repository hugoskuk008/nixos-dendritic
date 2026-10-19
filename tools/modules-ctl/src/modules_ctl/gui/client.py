"""Everything the GUI knows about modules-ctl, reached only by running its command line."""

import json
import shlex
import subprocess
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

import modules_ctl
from modules_ctl.errors import CLI_ERROR_PREFIX, ModulesCtlError
from modules_ctl.gui.model import ModuleCommand
from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus

CommandRunner = Callable[..., subprocess.CompletedProcess[str]]

_DISPLAY_NAME = "modules-ctl"


def _cli_program() -> tuple[str, ...]:
    """The command prefix that runs the CLI with the very package this process imported.

    Nix wraps Python programs so their package paths exist only inside the wrapped
    process; a bare interpreter started from it cannot import modules_ctl. The CLI
    needs nothing beyond the standard library, so naming where the package lives is enough.
    """
    package_root = Path(modules_ctl.__file__).resolve().parent.parent
    return ("env", f"PYTHONPATH={package_root}", sys.executable, "-m", "modules_ctl")


_PROGRAM = _cli_program()


class CliCommandError(ModulesCtlError):
    """modules-ctl exited with an error or printed something unreadable."""


@dataclass(frozen=True)
class ApplyOutcome:
    """How far a batch of commands got. Commands stop at the first failure."""

    applied: tuple[ModuleCommand, ...]
    failure: str | None = None

    @property
    def succeeded(self) -> bool:
        return self.failure is None


class CliClient:
    def __init__(self, repo: Path | None = None, run_command: CommandRunner = subprocess.run) -> None:
        self._repo = repo
        self._run_command = run_command

    def hosts(self) -> list[str]:
        output = self._invoke(["hosts", "--json"])
        names = _parse_json(output)
        if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
            raise CliCommandError("`hosts --json` did not print a list of names")
        return names

    def statuses(self, host: str) -> list[ModuleStatus]:
        records = _parse_json(self._invoke(["status", "--json"], host))
        try:
            return [
                ModuleStatus(ModuleKind(r["kind"]), r["name"], ModuleState(r["state"]))
                for r in records
            ]
        except (KeyError, TypeError, ValueError) as error:
            raise CliCommandError(f"`status --json` printed an unexpected record: {error}") from error

    def apply(self, host: str, commands: Sequence[ModuleCommand]) -> ApplyOutcome:
        applied: list[ModuleCommand] = []
        for command in commands:
            try:
                self._invoke(list(command.arguments), host)
            except CliCommandError as error:
                return ApplyOutcome(tuple(applied), str(error))
            applied.append(command)
        return ApplyOutcome(tuple(applied))

    def preview(self, host: str, command: ModuleCommand) -> str:
        """The command as a user would type it, for showing before it is sent."""
        return shlex.join([_DISPLAY_NAME, *self._global_flags(host), *command.arguments])

    def invocation(self, host: str, command: ModuleCommand) -> list[str]:
        """The complete argv that runs `command` for `host`, for launching outside this client."""
        return [*_PROGRAM, *self._global_flags(host), *command.arguments]

    def _invoke(self, arguments: list[str], host: str | None = None) -> str:
        completed = self._run_command(
            [*_PROGRAM, *self._global_flags(host), *arguments],
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            message = completed.stderr.strip().removeprefix(CLI_ERROR_PREFIX)
            raise CliCommandError(message or f"modules-ctl exited with status {completed.returncode}")
        return completed.stdout

    def _global_flags(self, host: str | None) -> list[str]:
        repo_flags = ["--repo", str(self._repo)] if self._repo else []
        host_flags = ["--host", host] if host else []
        return [*repo_flags, *host_flags]


def _parse_json(text: str) -> object:
    try:
        return json.loads(text)
    except json.JSONDecodeError as error:
        raise CliCommandError(f"modules-ctl printed invalid JSON: {error}") from error
