"""Classifying every module a host could use."""

from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus
from modules_ctl.registry import ModuleRegistry
from modules_ctl.selection import KindSelection, Selection

_KIND_ORDER = {kind: position for position, kind in enumerate(ModuleKind)}


def collect_statuses(selection: Selection, registry: ModuleRegistry) -> list[ModuleStatus]:
    """One status per module, kinds in declaration order, names alphabetical."""
    statuses = [
        status
        for kind in ModuleKind
        for status in classify_modules(kind, selection.of_kind(kind), registry.registered(kind))
    ]
    return sorted(statuses, key=lambda status: (_KIND_ORDER[status.kind], status.name))


def classify_modules(
    kind: ModuleKind, selection: KindSelection, registered: frozenset[str]
) -> list[ModuleStatus]:
    every_name = registered | selection.decided
    return [
        ModuleStatus(kind, name, _state_of(name, selection, registered))
        for name in sorted(every_name)
    ]


def _state_of(name: str, selection: KindSelection, registered: frozenset[str]) -> ModuleState:
    if name not in registered:
        return ModuleState.MISSING
    if name in selection.enabled:
        return ModuleState.ENABLED
    if name in selection.disabled:
        return ModuleState.DISABLED
    return ModuleState.NEW
