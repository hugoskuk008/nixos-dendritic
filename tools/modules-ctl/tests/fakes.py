import subprocess

from modules_ctl.model import ModuleKind


class FakeRegistry:
    """A registry with a fixed set of module names per kind."""

    def __init__(self, nixos: set[str] = frozenset(), home_manager: set[str] = frozenset()) -> None:
        self._by_kind = {
            ModuleKind.NIXOS: frozenset(nixos),
            ModuleKind.HOME_MANAGER: frozenset(home_manager),
        }

    def registered(self, kind: ModuleKind) -> frozenset[str]:
        return self._by_kind[kind]


class RecordingRunner:
    """Stands in for subprocess.run, replaying one canned result and noting each command."""

    def __init__(self, returncode: int = 0, stdout: str = "", stderr: str = "") -> None:
        self._result = (returncode, stdout, stderr)
        self.commands: list[list[str]] = []

    def __call__(self, command: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        self.commands.append(command)
        returncode, stdout, stderr = self._result
        return subprocess.CompletedProcess(command, returncode, stdout, stderr)


class ScriptedRunner:
    """Stands in for subprocess.run when the GUI client launches modules-ctl.

    Replies are keyed by the arguments after the `-m modules_ctl` launch prefix, joined by spaces.
    Anything unscripted succeeds with no output.
    """

    def __init__(self, replies: dict[str, tuple[int, str, str]] | None = None) -> None:
        self._replies = replies or {}
        self.invocations: list[str] = []

    def __call__(self, command: list[str], **_: object) -> subprocess.CompletedProcess[str]:
        key = " ".join(command[command.index("modules_ctl") + 1 :])
        self.invocations.append(key)
        returncode, stdout, stderr = self._replies.get(key, (0, "", ""))
        return subprocess.CompletedProcess(command, returncode, stdout, stderr)
