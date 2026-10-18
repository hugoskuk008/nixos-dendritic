"""A host's module choices as immutable values, independent of any file format."""

from collections.abc import Iterable, Mapping
from dataclasses import dataclass

from modules_ctl.errors import InvalidSelectionError
from modules_ctl.model import ModuleKind


@dataclass(frozen=True)
class KindSelection:
    """The user's decisions for the modules of one kind.

    A module is never both enabled and disabled. A module in neither set is
    undecided, which is what makes it show up as new.
    """

    enabled: frozenset[str] = frozenset()
    disabled: frozenset[str] = frozenset()

    def __post_init__(self) -> None:
        contradictory = self.enabled & self.disabled
        if contradictory:
            names = ", ".join(sorted(contradictory))
            raise InvalidSelectionError(f"both enabled and disabled: {names}")

    @property
    def decided(self) -> frozenset[str]:
        return self.enabled | self.disabled

    def enable(self, name: str) -> "KindSelection":
        return KindSelection(self.enabled | {name}, self.disabled - {name})

    def disable(self, name: str) -> "KindSelection":
        return KindSelection(self.enabled - {name}, self.disabled | {name})

    def forget(self, names: Iterable[str]) -> "KindSelection":
        forgotten = frozenset(names)
        return KindSelection(self.enabled - forgotten, self.disabled - forgotten)


@dataclass(frozen=True)
class Selection:
    """Every kind's decisions for one host. All kinds are always present."""

    by_kind: Mapping[ModuleKind, KindSelection]

    def __post_init__(self) -> None:
        if set(self.by_kind) != set(ModuleKind):
            raise ValueError("a Selection must hold an entry for every ModuleKind")

    @classmethod
    def empty(cls) -> "Selection":
        return cls({kind: KindSelection() for kind in ModuleKind})

    def of_kind(self, kind: ModuleKind) -> KindSelection:
        return self.by_kind[kind]

    def with_kind(self, kind: ModuleKind, kind_selection: KindSelection) -> "Selection":
        return Selection({**self.by_kind, kind: kind_selection})
