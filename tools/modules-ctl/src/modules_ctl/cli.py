"""Command-line front end: argument parsing, wiring, and presentation."""

import argparse
import json
import socket
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO

from modules_ctl.errors import CLI_ERROR_PREFIX, ModulesCtlError
from modules_ctl.model import ModuleKind, ModuleState, ModuleStatus
from modules_ctl.operations import disable_module, enable_module, forget_missing_modules
from modules_ctl.registry import (
    ModuleRegistry,
    NixModuleRegistry,
    expose_new_module_files_to_flake,
)
from modules_ctl.rebuild import Machine, run_rebuild
from modules_ctl.repository import host_directory, list_hosts, locate_repository
from modules_ctl.selection_file import load_selection, save_selection
from modules_ctl.status import collect_statuses

SELECTION_FILE_NAME = "modules.json"
DEFAULT_REPOSITORY_NAME = "nixos-dendritic"


@dataclass(frozen=True)
class Session:
    """Everything a host-specific command needs: where its file lives, what the flake offers."""

    selection_path: Path
    registry: ModuleRegistry
    out: TextIO


@dataclass(frozen=True)
class Workspace:
    """The repository being operated on, before any host has been chosen."""

    repo: Path
    out: TextIO
    machine: Machine
    registry: ModuleRegistry | None = None
    """Injected by tests; when absent, the flake itself is asked through nix."""

    def open_session(self, host: str) -> Session:
        directory = host_directory(self.repo, host)
        return Session(directory / SELECTION_FILE_NAME, self._registry(), self.out)

    def _registry(self) -> ModuleRegistry:
        if self.registry is not None:
            return self.registry
        expose_new_module_files_to_flake(self.repo)
        return NixModuleRegistry(self.repo)


def main(
    argv: Sequence[str] | None = None,
    *,
    registry: ModuleRegistry | None = None,
    out: TextIO | None = None,
    machine: Machine | None = None,
) -> int:
    """Run the CLI. `registry`, `out` and `machine` exist so tests can avoid nix, stdout and the OS."""
    args = _build_parser().parse_args(argv)
    try:
        repo = args.repo or locate_repository(Path.cwd(), Path.home() / DEFAULT_REPOSITORY_NAME)
        workspace = Workspace(repo, out or sys.stdout, machine or Machine.current(), registry)
        exit_status = args.command(workspace, args)
    except ModulesCtlError as error:
        print(f"{CLI_ERROR_PREFIX}{error}", file=sys.stderr)
        return 1
    return exit_status or 0


def _show_hosts(workspace: Workspace, args: argparse.Namespace) -> None:
    hosts = list_hosts(workspace.repo)
    if args.json:
        json.dump(hosts, workspace.out)
        workspace.out.write("\n")
    else:
        for host in hosts:
            workspace.out.write(f"{host}\n")


def _show_status(workspace: Workspace, args: argparse.Namespace) -> None:
    session = workspace.open_session(args.host)
    selection = load_selection(session.selection_path)
    statuses = collect_statuses(selection, session.registry)
    if args.json:
        json.dump([_status_as_dict(status) for status in statuses], session.out, indent=2)
        session.out.write("\n")
    else:
        for status in statuses:
            session.out.write(f"{status.state.value:<9} {status.kind.value:<12} {status.name}\n")


def _enable(workspace: Workspace, args: argparse.Namespace) -> None:
    session = workspace.open_session(args.host)
    selection = load_selection(session.selection_path)
    save_selection(session.selection_path, enable_module(selection, session.registry, args.kind, args.name))
    session.out.write(f"enabled {args.kind.value} module '{args.name}'\n")


def _disable(workspace: Workspace, args: argparse.Namespace) -> None:
    session = workspace.open_session(args.host)
    selection = load_selection(session.selection_path)
    save_selection(session.selection_path, disable_module(selection, session.registry, args.kind, args.name))
    session.out.write(f"disabled {args.kind.value} module '{args.name}'\n")


def _prune(workspace: Workspace, args: argparse.Namespace) -> None:
    session = workspace.open_session(args.host)
    selection = load_selection(session.selection_path)
    missing = [
        status
        for status in collect_statuses(selection, session.registry)
        if status.state is ModuleState.MISSING
    ]
    save_selection(session.selection_path, forget_missing_modules(selection, session.registry))
    for status in missing:
        session.out.write(f"removed missing {status.kind.value} module '{status.name}'\n")


def _rebuild(workspace: Workspace, args: argparse.Namespace) -> int:
    host_directory(workspace.repo, args.host)  # a typo should fail before anything runs
    return run_rebuild(
        workspace.repo, args.host, workspace.machine, workspace.out, force=args.force
    )


def _status_as_dict(status: ModuleStatus) -> dict[str, str]:
    return {"kind": status.kind.value, "name": status.name, "state": status.state.value}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="modules-ctl",
        description="Choose which dendritic modules a host imports.",
    )
    parser.add_argument(
        "--host",
        default=socket.gethostname(),
        help="directory name under hosts/ (default: this machine's hostname)",
    )
    parser.add_argument(
        "--repo",
        type=Path,
        help=(
            "flake root (default: nearest parent directory containing flake.nix, "
            f"else ~/{DEFAULT_REPOSITORY_NAME})"
        ),
    )
    commands = parser.add_subparsers(dest="command_name", required=True)

    hosts = commands.add_parser("hosts", help="list the hosts that have a directory under hosts/")
    hosts.add_argument("--json", action="store_true", help="machine-readable output")
    hosts.set_defaults(command=_show_hosts)

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

    rebuild = commands.add_parser("rebuild", help="switch this machine to the host's configuration")
    rebuild.add_argument(
        "--force", action="store_true", help="allow rebuilding a host that is not this machine"
    )
    rebuild.set_defaults(command=_rebuild)
    return parser
