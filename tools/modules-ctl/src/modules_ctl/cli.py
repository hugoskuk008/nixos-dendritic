"""Command-line front end: argument parsing, wiring, and presentation."""

import argparse
import json
import sys
import socket
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO

from modules_ctl.errors import HostNotFoundError, ModulesCtlError
from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus
from modules_ctl.operations import disable_module, enable_module, forget_missing_modules
from modules_ctl.registry import (
    ModuleRegistry,
    NixModuleRegistry,
    expose_new_module_files_to_flake,
)
from modules_ctl.selection_file import load_selection, save_selection
from modules_ctl.status import collect_statuses

SELECTION_FILE_NAME = "modules.json"


@dataclass(frozen=True)
class Session:
    """Everything a command needs: which host, where its file lives, what the flake offers."""

    selection_path: Path
    registry: ModuleRegistry
    out: TextIO


def main(
    argv: Sequence[str] | None = None,
    *,
    registry: ModuleRegistry | None = None,
    out: TextIO | None = None,
) -> int:
    """Run the CLI. `registry` and `out` exist so tests can avoid nix and stdout."""
    args = _build_parser().parse_args(argv)
    try:
        session = _open_session(args, registry, out or sys.stdout)
        args.command(session, args)
    except ModulesCtlError as error:
        print(f"modules-ctl: {error}", file=sys.stderr)
        return 1
    return 0


def _open_session(
    args: argparse.Namespace, registry: ModuleRegistry | None, out: TextIO
) -> Session:
    host_dir = args.repo / "hosts" / args.host
    if not host_dir.is_dir():
        raise HostNotFoundError(_describe_missing_host(args.repo, args.host))
    if registry is None:
        expose_new_module_files_to_flake(args.repo)
        registry = NixModuleRegistry(args.repo)
    return Session(host_dir / SELECTION_FILE_NAME, registry, out)


def _describe_missing_host(repo: Path, host: str) -> str:
    hosts_dir = repo / "hosts"
    available = sorted(path.name for path in hosts_dir.glob("*") if path.is_dir())
    return f"no host '{host}' under {hosts_dir} (available: {', '.join(available) or 'none'})"


def _show_status(session: Session, args: argparse.Namespace) -> None:
    selection = load_selection(session.selection_path)
    statuses = collect_statuses(selection, session.registry)
    if args.json:
        json.dump([_status_as_dict(status) for status in statuses], session.out, indent=2)
        session.out.write("\n")
    else:
        for status in statuses:
            session.out.write(f"{status.state.value:<9} {status.kind.value:<12} {status.name}\n")


def _enable(session: Session, args: argparse.Namespace) -> None:
    selection = load_selection(session.selection_path)
    save_selection(session.selection_path, enable_module(selection, session.registry, args.kind, args.name))
    session.out.write(f"enabled {args.kind.value} module '{args.name}'\n")


def _disable(session: Session, args: argparse.Namespace) -> None:
    selection = load_selection(session.selection_path)
    save_selection(session.selection_path, disable_module(selection, session.registry, args.kind, args.name))
    session.out.write(f"disabled {args.kind.value} module '{args.name}'\n")


def _prune(session: Session, args: argparse.Namespace) -> None:
    selection = load_selection(session.selection_path)
    missing = [
        status
        for status in collect_statuses(selection, session.registry)
        if status.state is ModuleState.MISSING
    ]
    save_selection(session.selection_path, forget_missing_modules(selection, session.registry))
    for status in missing:
        session.out.write(f"removed missing {status.kind.value} module '{status.name}'\n")


def _status_as_dict(status: ModuleStatus) -> dict[str, str]:
    return {"kind": status.kind.value, "name": status.name, "state": status.state.value}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="modules-ctl",
        description="Choose which dendritic modules a host imports.",
    )
    parser.add_argument (
            "--host",
            default=socket.gethostname(),
            help="directory name under hosts/ (default: this machine's hostname)")
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path.home() / "nixos-dendritic",
        help="flake root (default: ~/nixos-dendritic)",   
        )
    commands = parser.add_subparsers(dest="command_name", required=True)

    status = commands.add_parser("status", help="list every module with its state")
    status.add_argument("--json", action="store_true", help="machine-readable output")
    status.set_defaults(command=_show_status)

    for name, action, help_text in (
        ("enable", _enable, "import a module in this host"),
        ("disable", _disable, "stop importing a module in this host"),
    ):
        command = commands.add_parser(name, help=help_text)
        command.add_argument("kind", type=ModuleKind, metavar="{nixos,homeManager}")
        command.add_argument("name")
        command.set_defaults(command=action)

    prune = commands.add_parser("prune", help="remove entries for modules that no longer exist")
    prune.set_defaults(command=_prune)
    return parser
