"""Reading and writing a host's modules.json.

The file is the only thing a program edits, so its format is strict and its
output is deterministic: names are sorted and every kind is written, which
keeps git diffs limited to real changes.

    {
      "nixos":       {"enabled": ["system"], "disabled": ["tailscale"]},
      "homeManager": {"enabled": ["zsh"],    "disabled": []}
    }
"""

import json
import os
import tempfile
from pathlib import Path
from typing import Any

from modules_ctl.errors import InvalidSelectionError
from modules_ctl.model import ModuleKind
from modules_ctl.selection import KindSelection, Selection

_KIND_KEYS = frozenset(kind.value for kind in ModuleKind)
_LIST_KEYS = frozenset({"enabled", "disabled"})


def parse_selection(text: str) -> Selection:
    document = _as_object(_load_json(text), "top level")
    _reject_unknown_keys(document, _KIND_KEYS, "top level")
    return Selection(
        {kind: _parse_kind_selection(kind, document.get(kind.value, {})) for kind in ModuleKind}
    )


def render_selection(selection: Selection) -> str:
    document = {
        kind.value: {
            "enabled": sorted(selection.of_kind(kind).enabled),
            "disabled": sorted(selection.of_kind(kind).disabled),
        }
        for kind in ModuleKind
    }
    return json.dumps(document, indent=2) + "\n"


def load_selection(path: Path) -> Selection:
    """Read a host's selection; a host with no file yet has decided nothing."""
    if not path.exists():
        return Selection.empty()
    try:
        return parse_selection(path.read_text(encoding="utf-8"))
    except InvalidSelectionError as error:
        raise InvalidSelectionError(f"{path}: {error}") from error


def save_selection(path: Path, selection: Selection) -> None:
    """Write atomically so a crash never leaves a half-written file for nix to read."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent, suffix=".tmp", delete=False
    ) as scratch:
        scratch.write(render_selection(selection))
    try:
        os.replace(scratch.name, path)
    except OSError:
        os.unlink(scratch.name)
        raise


def _parse_kind_selection(kind: ModuleKind, raw: Any) -> KindSelection:
    section = _as_object(raw, kind.value)
    _reject_unknown_keys(section, _LIST_KEYS, kind.value)
    try:
        return KindSelection(
            enabled=_names(section, "enabled", kind),
            disabled=_names(section, "disabled", kind),
        )
    except InvalidSelectionError as error:
        raise InvalidSelectionError(f"{kind.value}: {error}") from error


def _names(section: dict[str, Any], key: str, kind: ModuleKind) -> frozenset[str]:
    names = section.get(key, [])
    if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
        raise InvalidSelectionError(f"{kind.value}.{key} must be a list of module names")
    return frozenset(names)


def _load_json(text: str) -> Any:
    try:
        return json.loads(text)
    except json.JSONDecodeError as error:
        raise InvalidSelectionError(f"not valid JSON: {error}") from error


def _as_object(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise InvalidSelectionError(f"{where} must be a JSON object")
    return value


def _reject_unknown_keys(section: dict[str, Any], allowed: frozenset[str], where: str) -> None:
    unknown = sorted(set(section) - allowed)
    if unknown:
        raise InvalidSelectionError(f"unknown key(s) in {where}: {', '.join(unknown)}")
