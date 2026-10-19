"""Rebuilding the running system from a host's configuration."""

import shlex
import shutil
import socket
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO

from modules_ctl.errors import RebuildRefusedError
from modules_ctl.registry import CommandRunner


@dataclass(frozen=True)
class Machine:
    """What modules-ctl asks of the computer it runs on; tests substitute their own."""

    hostname: str
    has_nh: bool
    run_command: CommandRunner

    @classmethod
    def current(cls) -> "Machine":
        return cls(socket.gethostname(), shutil.which("nh") is not None, subprocess.run)


def targets_machine(host: str, hostname: str) -> bool:
    """Whether a host's configuration describes the machine named `hostname`."""
    return host == hostname


def rebuild_command(repo: Path, host: str, *, has_nh: bool) -> list[str]:
    """The command that switches this machine to `host`'s configuration from `repo`."""
    if has_nh:
        return ["nh", "os", "switch", str(repo), "--hostname", host]
    return ["sudo", "nixos-rebuild", "switch", "--flake", f"{repo}#{host}"]


def run_rebuild(
    repo: Path, host: str, machine: Machine, out: TextIO, *, force: bool = False
) -> int:
    """Run the rebuild attached to the terminal, so output and password prompts reach the user."""
    if not force and not targets_machine(host, machine.hostname):
        raise RebuildRefusedError(
            f"host '{host}' is not this machine ('{machine.hostname}'); switching would "
            f"reconfigure this machine with {host}'s configuration. Use --force if that is intended"
        )
    command = rebuild_command(repo, host, has_nh=machine.has_nh)
    out.write(f"$ {shlex.join(command)}\n")
    out.flush()
    return machine.run_command(command, check=False).returncode
