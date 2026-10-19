"""GTK 4 window: pick a host, enable or disable modules, send the commands to modules-ctl, rebuild.

This file only draws widgets and forwards clicks and key presses. What the user has chosen
lives in ModuleListModel, talking to modules-ctl lives in CliClient, and opening a terminal
lives in terminal.py.

Keyboard: Ctrl+F searches the list. Ctrl+X applies pending changes and then rebuilds.
"""

import argparse
import socket
import sys
import threading
from collections.abc import Callable
from pathlib import Path
from typing import TypeVar

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

from modules_ctl.errors import ModulesCtlError  # noqa: E402
from modules_ctl.gui.client import ApplyOutcome, CliClient  # noqa: E402
from modules_ctl.gui.model import (  # noqa: E402
    ModuleCommand,
    ModuleKey,
    ModuleListModel,
    matches_search,
    preferred_host,
)
from modules_ctl.gui.terminal import TerminalError, launch_in_terminal  # noqa: E402
from modules_ctl.model import ModuleState, ModuleStatus  # noqa: E402
from modules_ctl.rebuild import targets_machine  # noqa: E402

APPLICATION_ID = "org.modulesctl.Gui"

DARK_THEME_CSS = """
window { background-color: #1e2127; color: #d7dae0; }
list, row { background-color: transparent; }
row { border-bottom: 1px solid #2c313a; }
.changed { color: #e5c07b; font-weight: bold; }
.command-preview { background-color: #16181d; padding: 8px; }
"""

Result = TypeVar("Result")


def run_in_background(
    work: Callable[[], Result],
    on_success: Callable[[Result], None],
    on_failure: Callable[[Exception], None],
) -> None:
    """Run slow work (nix, subprocesses) off the UI thread; deliver the outcome on it."""

    def deliver_on_ui_thread(callback: Callable[..., None], argument: object) -> bool:
        callback(argument)
        return GLib.SOURCE_REMOVE

    def worker() -> None:
        try:
            result = work()
        except Exception as error:  # a failure must reach the user, not die inside a thread
            GLib.idle_add(deliver_on_ui_thread, on_failure, error)
        else:
            GLib.idle_add(deliver_on_ui_thread, on_success, result)

    threading.Thread(target=worker, daemon=True).start()


def apply_dark_theme() -> None:
    Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme", True)
    provider = Gtk.CssProvider()
    provider.load_from_string(DARK_THEME_CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )


def shortcut(accelerator: str, handler: Callable[[], None]) -> Gtk.Shortcut:
    def run(_widget: Gtk.Widget, _arguments: object) -> bool:
        handler()
        return True  # the key press is consumed, even where a text field would also use it

    return Gtk.Shortcut.new(
        Gtk.ShortcutTrigger.parse_string(accelerator), Gtk.CallbackAction.new(run)
    )


class ModuleRow(Gtk.ListBoxRow):
    """One module: its name, kind, saved state, and an Enable / Disable choice."""

    def __init__(
        self,
        status: ModuleStatus,
        shown_state: ModuleState,
        on_choice: Callable[[ModuleStatus, ModuleState], None],
    ) -> None:
        super().__init__()
        self.module_status = status
        self._on_choice = on_choice
        self._name_label = Gtk.Label(label=status.name, xalign=0, hexpand=True)

        layout = Gtk.Box(spacing=12, margin_top=6, margin_bottom=6, margin_start=12, margin_end=12)
        layout.append(self._name_label)
        layout.append(Gtk.Label(label=status.kind.value, css_classes=["dim-label"]))
        layout.append(Gtk.Label(label=status.state.value, width_chars=8, css_classes=["dim-label"]))
        layout.append(self._build_choice(shown_state))
        self.set_child(layout)

    def show_changed(self, changed: bool) -> None:
        if changed:
            self._name_label.add_css_class("changed")
        else:
            self._name_label.remove_css_class("changed")

    def _build_choice(self, shown_state: ModuleState) -> Gtk.Box:
        enable = Gtk.ToggleButton(label="Enable")
        disable = Gtk.ToggleButton(label="Disable")
        disable.set_group(enable)
        enable.set_active(shown_state is ModuleState.ENABLED)
        disable.set_active(shown_state is ModuleState.DISABLED)

        choice = Gtk.Box(css_classes=["linked"])
        for button, decision in ((enable, ModuleState.ENABLED), (disable, ModuleState.DISABLED)):
            button.set_sensitive(self.module_status.state is not ModuleState.MISSING)
            button.connect("toggled", self._on_toggled, decision)
            choice.append(button)
        return choice

    def _on_toggled(self, button: Gtk.ToggleButton, decision: ModuleState) -> None:
        if button.get_active():
            self._on_choice(self.module_status, decision)


class ModulesWindow(Gtk.ApplicationWindow):
    def __init__(
        self,
        application: Gtk.Application,
        client: CliClient,
        hosts: list[str],
        initial_host: str | None,
        this_machine: str,
    ) -> None:
        super().__init__(application=application, title="Modules", default_width=680, default_height=780)
        self._client = client
        self._hosts = hosts
        self._host = initial_host
        self._this_machine = this_machine
        self._model = ModuleListModel([])
        self._rows: dict[ModuleKey, ModuleRow] = {}
        self._busy = False

        self._build_header()
        self._build_body()
        self._install_shortcuts()
        if initial_host is None:
            self._set_idle("No hosts found under hosts/")
        else:
            self._load_statuses()

    def _build_header(self) -> None:
        header = Gtk.HeaderBar()
        if self._hosts:
            self._host_dropdown = Gtk.DropDown.new_from_strings(self._hosts)
            self._host_dropdown.set_selected(self._hosts.index(self._host))
            self._host_dropdown.connect("notify::selected", self._on_host_selected)
            header.pack_start(self._host_dropdown)
        self.set_titlebar(header)

    def _build_body(self) -> None:
        self._search_entry = Gtk.SearchEntry(
            hexpand=True, placeholder_text="Search by name, kind or state, e.g. 'new' or 'nixos hypr'"
        )
        self._search_entry.connect("search-changed", lambda _entry: self._list.invalidate_filter())
        self._search_bar = Gtk.SearchBar()
        self._search_bar.set_child(self._search_entry)
        self._search_bar.connect_entry(self._search_entry)
        self._search_bar.connect("notify::search-mode-enabled", self._on_search_mode_changed)

        self._list = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE)
        self._list.set_filter_func(self._row_matches_search)
        scroller = Gtk.ScrolledWindow(vexpand=True)
        scroller.set_child(self._list)

        self._prune_check = Gtk.CheckButton()
        self._prune_check.connect("toggled", self._on_prune_toggled)

        self._preview = Gtk.Label(
            xalign=0, selectable=True, wrap=True, css_classes=["monospace", "command-preview"]
        )

        self._message = Gtk.Label(xalign=0, hexpand=True, wrap=True)
        self._revert_button = Gtk.Button(label="Revert")
        self._revert_button.connect("clicked", self._on_revert)
        self._apply_button = Gtk.Button(label="Apply")
        self._apply_button.connect("clicked", self._on_apply)
        self._rebuild_button = Gtk.Button(label="Rebuild", css_classes=["suggested-action"])
        self._rebuild_button.connect("clicked", self._on_apply_and_rebuild)
        actions = Gtk.Box(spacing=8)
        for widget in (self._message, self._revert_button, self._apply_button, self._rebuild_button):
            actions.append(widget)

        body = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=8, margin_top=8, margin_bottom=12, margin_start=12, margin_end=12,
        )
        for widget in (self._search_bar, scroller, self._prune_check, self._preview, actions):
            body.append(widget)
        self.set_child(body)

    def _install_shortcuts(self) -> None:
        controller = Gtk.ShortcutController()
        # Capture, so Ctrl+X reaches us even while the search box has focus (where it would cut text).
        controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        controller.add_shortcut(shortcut("<Control>f", self._on_find))
        controller.add_shortcut(shortcut("<Control>x", self._on_apply_and_rebuild))
        self.add_controller(controller)

    # --- loading -------------------------------------------------------------------------

    def _load_statuses(self, announce: str = "") -> None:
        host = self._host
        self._set_busy(f"Loading modules for {host}…")

        def show(statuses: list[ModuleStatus]) -> None:
            if host == self._host:  # the user may have switched hosts while this loaded
                self._show_statuses(statuses, announce)

        run_in_background(lambda: self._client.statuses(host), show, self._on_failed)

    def _show_statuses(self, statuses: list[ModuleStatus], announce: str) -> None:
        self._model = ModuleListModel(statuses)
        self._rebuild_rows()
        missing = self._model.missing_count
        self._prune_check.set_visible(missing > 0)
        self._prune_check.set_label(f"Remove {missing} entries for modules that no longer exist")
        self._prune_check.set_active(False)
        self._set_idle(announce)

    def _rebuild_rows(self) -> None:
        while (row := self._list.get_first_child()) is not None:
            self._list.remove(row)
        self._rows.clear()
        for status in self._model.statuses:
            row = ModuleRow(status, self._model.shown_state(status), self._on_choice)
            self._rows[(status.kind, status.name)] = row
            self._list.append(row)

    # --- search --------------------------------------------------------------------------

    def _on_find(self) -> None:
        self._search_bar.set_search_mode(True)
        self._search_entry.grab_focus()

    def _on_search_mode_changed(self, search_bar: Gtk.SearchBar, _parameter: object) -> None:
        if not search_bar.get_search_mode():
            self._search_entry.set_text("")  # a hidden search must not keep filtering the list

    def _row_matches_search(self, row: ModuleRow) -> bool:
        return matches_search(row.module_status, self._search_entry.get_text())

    # --- user choices --------------------------------------------------------------------

    def _on_choice(self, status: ModuleStatus, decision: ModuleState) -> None:
        self._model.decide(status, decision)
        self._rows[(status.kind, status.name)].show_changed(self._model.is_changed(status))
        self._refresh_pending()

    def _on_prune_toggled(self, button: Gtk.CheckButton) -> None:
        self._model.prune_missing = button.get_active()
        self._refresh_pending()

    def _on_host_selected(self, dropdown: Gtk.DropDown, _parameter: object) -> None:
        host = self._hosts[dropdown.get_selected()]
        if host != self._host:
            self._host = host
            self._load_statuses()

    def _on_revert(self, _button: Gtk.Button) -> None:
        self._model.discard_changes()
        self._prune_check.set_active(False)
        self._rebuild_rows()
        self._refresh_pending()

    # --- applying and rebuilding ---------------------------------------------------------

    def _on_apply(self, _button: Gtk.Button) -> None:
        self._apply(then_rebuild=False)

    def _on_apply_and_rebuild(self, _button: Gtk.Button | None = None) -> None:
        if self._busy:
            return
        if not self._rebuild_allowed():
            self._message.set_text(self._rebuild_blocked_reason())
            return
        self._apply(then_rebuild=True)

    def _apply(self, then_rebuild: bool) -> None:
        host, commands = self._host, self._model.pending_commands()
        if not commands:
            if then_rebuild:
                self._message.set_text(self._start_rebuild())
            return
        self._set_busy("Applying…")
        run_in_background(
            lambda: self._client.apply(host, commands),
            lambda outcome: self._on_applied(len(commands), outcome, then_rebuild),
            self._on_failed,
        )

    def _on_applied(self, total: int, outcome: ApplyOutcome, then_rebuild: bool) -> None:
        if not outcome.succeeded:
            message = f"Stopped after {len(outcome.applied)} of {total}: {outcome.failure}"
        elif then_rebuild:
            message = f"Applied {total} change(s). {self._start_rebuild()}"
        else:
            message = f"Applied {total} change(s). Rebuild the system to activate them."
        self._load_statuses(announce=message)

    def _start_rebuild(self) -> str:
        """Open a terminal running `modules-ctl rebuild`, which works out the path and host itself."""
        try:
            terminal = launch_in_terminal(self._client.invocation(self._host, ModuleCommand.rebuild()))
        except TerminalError as error:
            return f"Could not start the rebuild: {error}"
        return f"Rebuild started in {terminal}."

    def _rebuild_allowed(self) -> bool:
        return self._host is not None and targets_machine(self._host, self._this_machine)

    def _rebuild_blocked_reason(self) -> str:
        return (
            f"Rebuild is only offered for this machine's own host ('{self._this_machine}'); "
            "use `modules-ctl rebuild --force` to rebuild another."
        )

    # --- status line and button state ----------------------------------------------------

    def _on_failed(self, error: Exception) -> None:
        self._set_idle(f"Error: {error}")

    def _set_busy(self, message: str) -> None:
        self._busy = True
        self._message.set_text(message)
        self._refresh_pending()

    def _set_idle(self, message: str) -> None:
        self._busy = False
        self._message.set_text(message)
        self._refresh_pending()

    def _refresh_pending(self) -> None:
        commands = self._model.pending_commands()
        self._preview.set_text(
            "\n".join(self._client.preview(self._host, command) for command in commands)
            or "No changes"
        )
        can_act = bool(commands) and not self._busy
        self._apply_button.set_sensitive(can_act)
        self._revert_button.set_sensitive(can_act)
        self._refresh_rebuild_button(has_changes=bool(commands))

    def _refresh_rebuild_button(self, has_changes: bool) -> None:
        allowed = self._rebuild_allowed()
        self._rebuild_button.set_label("Apply & Rebuild" if has_changes else "Rebuild")
        self._rebuild_button.set_sensitive(allowed and not self._busy)
        if allowed:
            command = self._client.preview(self._host, ModuleCommand.rebuild())
            self._rebuild_button.set_tooltip_text(f"Opens a terminal and runs: {command}  (Ctrl+X)")
        else:
            self._rebuild_button.set_tooltip_text(self._rebuild_blocked_reason())


class ModulesApplication(Gtk.Application):
    def __init__(
        self, client: CliClient, hosts: list[str], initial_host: str | None, this_machine: str
    ) -> None:
        super().__init__(application_id=APPLICATION_ID)
        self._client = client
        self._hosts = hosts
        self._initial_host = initial_host
        self._this_machine = this_machine

    def do_activate(self) -> None:
        apply_dark_theme()
        ModulesWindow(
            self, self._client, self._hosts, self._initial_host, self._this_machine
        ).present()


def main() -> int:
    parser = argparse.ArgumentParser(prog="modules-ctl-gui", description="Choose host modules.")
    parser.add_argument("--repo", type=Path, help="flake root (default: as for modules-ctl)")
    args = parser.parse_args()

    client = CliClient(args.repo)
    try:
        hosts = client.hosts()
    except ModulesCtlError as error:
        print(f"modules-ctl-gui: {error}", file=sys.stderr)
        return 1
    this_machine = socket.gethostname()
    application = ModulesApplication(client, hosts, preferred_host(hosts, this_machine), this_machine)
    return application.run([sys.argv[0]])
