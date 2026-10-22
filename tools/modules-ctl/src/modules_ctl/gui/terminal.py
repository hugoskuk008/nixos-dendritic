"""Opening a command in a terminal window that stays open until the user has read the output."""

import os
import shlex
import shutil
import subprocess
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path

from modules_ctl.errors import ModulesCtlError

# How each known terminal is told to run a program. Candidates are tried in this order.
_RUN_ARGUMENTS: dict[str, tuple[str, ...]] = {
    "kitty": (),
    "foot": (),
    "alacritty": ("-e",),
    "wezterm": ("start", "--"),
    "gnome-terminal": ("--",),
    "konsole": ("-e",),
}
_UNKNOWN_TERMINAL_RUN_ARGUMENTS = ("-e",)  # the convention nearly every terminal follows

Which = Callable[[str], str | None]


class TerminalError(ModulesCtlError):
    """No terminal could be found or started."""


def launch_in_terminal(
    argv: Sequence[str],
    environ: Mapping[str, str] = os.environ,
    which: Which = shutil.which,
    spawn: Callable[..., object] = subprocess.Popen,
) -> str:
    """Start `argv` in a new terminal, detached from this process. Returns the terminal's name."""
    invocation = terminal_invocation(argv, environ, which)
    try:
        spawn(invocation, start_new_session=True)
    except OSError as error:
        raise TerminalError(f"could not start {invocation[0]}: {error}") from error
    return Path(invocation[0]).name


def terminal_invocation(
    argv: Sequence[str], environ: Mapping[str, str], which: Which
) -> list[str]:
    terminal = _choose_terminal(environ, which)
    run_arguments = _RUN_ARGUMENTS.get(Path(terminal).name, _UNKNOWN_TERMINAL_RUN_ARGUMENTS)
    return [terminal, *run_arguments, *_hold_open_after(argv)]


def _choose_terminal(environ: Mapping[str, str], which: Which) -> str:
    """$TERMINAL if it names a real program, otherwise the first known terminal installed."""
    preferred = environ.get("TERMINAL")
    candidates = ([preferred] if preferred else []) + list(_RUN_ARGUMENTS)
    for candidate in candidates:
        found = which(candidate)
        if found:
            return found
    raise TerminalError("no terminal found; set $TERMINAL to your terminal's command")


def _hold_open_after(argv: Sequence[str]) -> list[str]:
    """Wrap a command so the window waits for Enter instead of vanishing with the output."""
    script = (
        f'{shlex.join(argv)}; status=$?; '
        'printf "\\nFinished with exit status %s. Press Enter to close. " "$status"; '
        'read -r _; exit "$status"'
    )
    return ["bash", "-c", script]
