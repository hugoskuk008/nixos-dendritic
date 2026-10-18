"""Vocabulary shared by every other module in modules_ctl."""

from dataclasses import dataclass
from enum import Enum


class ModuleKind(str, Enum):
    """The module system a module is registered under: `flake.modules.<kind>`."""

    NIXOS = "nixos"
    HOME_MANAGER = "homeManager"


class ModuleState(str, Enum):
    """Where a module stands relative to one host's selection."""

    ENABLED = "enabled"
    """Imported by the host's build."""

    DISABLED = "disabled"
    """Deliberately switched off by the user."""

    NEW = "new"
    """Registered by the flake, but the user has not decided on it yet."""

    MISSING = "missing"
    """Listed in the selection, but the flake no longer registers it."""


@dataclass(frozen=True)
class ModuleStatus:
    kind: ModuleKind
    name: str
    state: ModuleState
