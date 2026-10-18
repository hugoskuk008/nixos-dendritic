"""Changing a host's selection. Each operation returns a new Selection."""

from modules_ctl.errors import UnknownModuleError
from modules_ctl.model import ModuleKind
from modules_ctl.registry import ModuleRegistry
from modules_ctl.selection import Selection


def enable_module(
    selection: Selection, registry: ModuleRegistry, kind: ModuleKind, name: str
) -> Selection:
    _require_registered(registry, kind, name)
    return selection.with_kind(kind, selection.of_kind(kind).enable(name))


def disable_module(
    selection: Selection, registry: ModuleRegistry, kind: ModuleKind, name: str
) -> Selection:
    _require_registered(registry, kind, name)
    return selection.with_kind(kind, selection.of_kind(kind).disable(name))


def forget_missing_modules(selection: Selection, registry: ModuleRegistry) -> Selection:
    """Drop entries for modules the flake no longer registers.

    Such entries would otherwise fail the build, which imports every enabled name.
    """
    for kind in ModuleKind:
        kind_selection = selection.of_kind(kind)
        missing = kind_selection.decided - registry.registered(kind)
        selection = selection.with_kind(kind, kind_selection.forget(missing))
    return selection


def _require_registered(registry: ModuleRegistry, kind: ModuleKind, name: str) -> None:
    registered = registry.registered(kind)
    if name not in registered:
        known = ", ".join(sorted(registered)) or "none"
        raise UnknownModuleError(
            f"no {kind.value} module named '{name}' is registered (registered: {known})"
        )
