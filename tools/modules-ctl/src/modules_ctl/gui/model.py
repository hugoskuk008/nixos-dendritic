"""Toolkit-free state of the module list: what the user has chosen and what to run for it."""

from collections.abc import Sequence
from dataclasses import dataclass

from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus

ModuleKey = tuple[ModuleKind, str]


@dataclass(frozen=True)
class ModuleCommand:
    """One modules-ctl invocation, without the global --repo and --host flags."""

    arguments: tuple[str, ...]

    @classmethod
    def enable(cls, kind: ModuleKind, name: str) -> "ModuleCommand":
        return cls(("enable", kind.value, name))

    @classmethod
    def disable(cls, kind: ModuleKind, name: str) -> "ModuleCommand":
        return cls(("disable", kind.value, name))

    @classmethod
    def prune(cls) -> "ModuleCommand":
        return cls(("prune",))

    @classmethod
    def rebuild(cls) -> "ModuleCommand":
        return cls(("rebuild",))


_COMMAND_FOR_DECISION = {
    ModuleState.ENABLED: ModuleCommand.enable,
    ModuleState.DISABLED: ModuleCommand.disable,
}


class ModuleListModel:
    """The saved state of every module plus the user's not-yet-applied choices."""

    def __init__(self, statuses: Sequence[ModuleStatus]) -> None:
        self._statuses = tuple(statuses)
        self._decisions: dict[ModuleKey, ModuleState] = {}
        self.prune_missing = False

    @property
    def statuses(self) -> tuple[ModuleStatus, ...]:
        return self._statuses

    @property
    def missing_count(self) -> int:
        return sum(1 for status in self._statuses if status.state is ModuleState.MISSING)

    def decide(self, status: ModuleStatus, decision: ModuleState) -> None:
        """Choose enabled or disabled; choosing the saved state again withdraws the change."""
        if status.state is ModuleState.MISSING:
            raise ValueError(f"'{status.name}' no longer exists and can only be removed (prune)")
        if decision not in _COMMAND_FOR_DECISION:
            raise ValueError("a module can only be decided as enabled or disabled")
        if decision is status.state:
            self._decisions.pop(_key(status), None)
        else:
            self._decisions[_key(status)] = decision

    def shown_state(self, status: ModuleStatus) -> ModuleState:
        return self._decisions.get(_key(status), status.state)

    def is_changed(self, status: ModuleStatus) -> bool:
        return _key(status) in self._decisions

    def pending_commands(self) -> list[ModuleCommand]:
        """Commands that turn the saved state into the chosen one, in list order."""
        commands = [
            _COMMAND_FOR_DECISION[self._decisions[_key(status)]](status.kind, status.name)
            for status in self._statuses
            if _key(status) in self._decisions
        ]
        if self.prune_missing and self.missing_count:
            commands.append(ModuleCommand.prune())
        return commands

    def discard_changes(self) -> None:
        self._decisions.clear()
        self.prune_missing = False


def matches_search(status: ModuleStatus, query: str) -> bool:
    """Whether every word of `query` appears in the module's kind, name or state."""
    searchable = f"{status.kind.value} {status.name} {status.state.value}".lower()
    return all(word in searchable for word in query.lower().split())


def preferred_host(hosts: Sequence[str], hostname: str) -> str | None:
    """This machine's own host if it has one, otherwise the first host, otherwise none."""
    if hostname in hosts:
        return hostname
    return hosts[0] if hosts else None


def _key(status: ModuleStatus) -> ModuleKey:
    return (status.kind, status.name)
