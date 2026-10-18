"""Tkinter front end for modules-ctl.

The GUI is deliberately a thin shell over the CLI: it reads state with
``modules-ctl status --json`` and, on Apply, runs one
``modules-ctl enable|disable <kind> <name>`` per pending change.  That keeps
every write going through the same tested code path as the command line.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tkinter as tk
from dataclasses import dataclass
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from modules_ctl.model import ModuleState

DEFAULT_REPO = Path.home() / "nixos-dendritic"
SELECTION_FILE_NAME = "modules.json"

# Tkinter has no built-in dark theme, so we restyle the "clam" engine.
# Two small palettes keep light mode one toggle away.
_PALETTES = {
    "dark": {
        "bg": "#1e1e2e",
        "surface": "#2a2a3c",
        "field": "#242436",
        "border": "#3a3b52",
        "fg": "#cdd6f4",
        "select": "#45475a",
        "log": "#181825",
        "tag_enabled": "#a6e3a1",
        "tag_disabled": "#7f849c",
        "tag_new": "#fab387",
        "tag_missing": "#f38ba8",
        "tag_changed": "#4d4318",
    },
    "light": {
        "bg": "#f5f5f5",
        "surface": "#e8e8e8",
        "field": "#ffffff",
        "border": "#c0c0c0",
        "fg": "#1a1a1a",
        "select": "#c8dcf0",
        "log": "#ffffff",
        "tag_enabled": "#2e7d32",
        "tag_disabled": "#9e9e9e",
        "tag_new": "#ef6c00",
        "tag_missing": "#c62828",
        "tag_changed": "#fff3cd",
    },
}


@dataclass
class ModuleRow:
    """One line in the picker: current state plus the user's pending choice."""

    kind: str
    name: str
    current: str
    desired: str | None = None  # None means "leave as loaded"

    @property
    def changed(self) -> bool:
        return self.desired is not None and self.desired != self.current

    @property
    def effective(self) -> str:
        return self.desired if self.desired is not None else self.current


def plan_changes(rows: list[ModuleRow]) -> list[tuple[str, str, str]]:
    """Diff loaded state against the UI's choices -> (operation, kind, name)."""
    return [
        (
            "enable" if row.desired == ModuleState.ENABLED.value else "disable",
            row.kind,
            row.name,
        )
        for row in rows
        if row.changed
    ]


def ctl_argv() -> list[str]:
    """How to invoke the CLI: installed binary, else this same package."""
    binary = shutil.which("modules-ctl")
    return [binary] if binary else [sys.executable, "-m", "modules_ctl"]


def list_hosts(repo: Path) -> list[str]:
    """Host directories that hold a modules.json selection file."""
    hosts_dir = repo / "hosts"
    if not hosts_dir.is_dir():
        return []
    return sorted(
        path.name for path in hosts_dir.iterdir()
        if path.is_dir() and (path / SELECTION_FILE_NAME).is_file()
    )


def parse_status(payload: str) -> list[ModuleRow]:
    """Turn `modules-ctl status --json` output into picker rows."""
    return [
        ModuleRow(kind=entry["kind"], name=entry["name"], current=entry["state"])
        for entry in json.loads(payload)
    ]


class ModulePickerApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("modules-ctl — module picker")
        self.geometry("760x560")
        self.minsize(640, 480)

        self.repo_var = tk.StringVar(value=str(DEFAULT_REPO))
        self.host_var = tk.StringVar()
        self.dark_var = tk.BooleanVar(value=True)
        self.rows: list[ModuleRow] = []

        self._build_widgets()
        self._apply_theme()
        self._refresh_hosts()

    # -- layout -----------------------------------------------------------

    def _build_widgets(self) -> None:
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        top = ttk.Frame(self, padding=8)
        top.grid(row=0, column=0, sticky="ew")
        top.columnconfigure(1, weight=1)

        ttk.Label(top, text="Repo:").grid(row=0, column=0, sticky="w")
        ttk.Entry(top, textvariable=self.repo_var).grid(row=0, column=1, sticky="ew", padx=4)
        ttk.Button(top, text="Browse…", command=self._browse_repo).grid(row=0, column=2)

        ttk.Label(top, text="Host:").grid(row=1, column=0, sticky="w", pady=(6, 0))
        self.host_box = ttk.Combobox(
            top, textvariable=self.host_var, state="readonly", width=24
        )
        self.host_box.grid(row=1, column=1, sticky="w", padx=4, pady=(6, 0))
        ttk.Button(top, text="Refresh hosts", command=self._refresh_hosts).grid(
            row=1, column=2, pady=(6, 0)
        )
        ttk.Button(top, text="Load modules", command=self._load_status).grid(
            row=1, column=3, padx=(4, 0), pady=(6, 0)
        )
        ttk.Checkbutton(
            top, text="Dark", variable=self.dark_var, command=self._apply_theme
        ).grid(row=1, column=4, padx=(12, 0), pady=(6, 0))

        middle = ttk.Frame(self, padding=(8, 0))
        middle.grid(row=1, column=0, sticky="nsew")
        middle.columnconfigure(0, weight=1)
        middle.rowconfigure(0, weight=1)

        self.tree = ttk.Treeview(
            middle, columns=("state", "kind", "name"), show="headings", selectmode="extended"
        )
        for column, label, width in (
            ("state", "State", 140),
            ("kind", "Kind", 120),
            ("name", "Module", 320),
        ):
            self.tree.heading(column, text=label)
            self.tree.column(column, width=width, anchor="w")
        self.tree.grid(row=0, column=0, sticky="nsew")
        self.tree.bind("<Double-1>", lambda _event: self._toggle_selected())

        scrollbar = ttk.Scrollbar(middle, orient="vertical", command=self.tree.yview)
        scrollbar.grid(row=0, column=1, sticky="ns")
        self.tree.configure(yscrollcommand=scrollbar.set)

        actions = ttk.Frame(self, padding=8)
        actions.grid(row=2, column=0, sticky="ew")
        ttk.Button(actions, text="Enable", command=lambda: self._set_selected(True)).pack(
            side="left"
        )
        ttk.Button(actions, text="Disable", command=lambda: self._set_selected(False)).pack(
            side="left", padx=4
        )
        ttk.Button(actions, text="Toggle (double-click)", command=self._toggle_selected).pack(
            side="left"
        )
        ttk.Button(actions, text="Revert changes", command=self._revert).pack(side="left", padx=4)
        self.apply_button = ttk.Button(
            actions, text="Apply", command=self._apply, state="disabled"
        )
        self.apply_button.pack(side="right")

        self.preview_var = tk.StringVar(value="No changes.")
        ttk.Label(self, textvariable=self.preview_var, padding=(8, 0)).grid(
            row=3, column=0, sticky="ew"
        )

        self.log = tk.Text(self, height=6, wrap="word", state="disabled")
        self.log.grid(row=4, column=0, sticky="ew", padx=8, pady=(0, 8))

    # -- theme ------------------------------------------------------------

    def _apply_theme(self) -> None:
        """Restyle every widget from the active palette (clam-based, no deps)."""
        palette = _PALETTES["dark" if self.dark_var.get() else "light"]
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass  # clam is always present, but never hard-fail on it

        self.configure(bg=palette["bg"])
        style.configure(
            ".",
            background=palette["bg"],
            foreground=palette["fg"],
            fieldbackground=palette["field"],
            bordercolor=palette["border"],
            darkcolor=palette["border"],
            lightcolor=palette["border"],
            troughcolor=palette["field"],
            selectbackground=palette["select"],
            selectforeground=palette["fg"],
            insertcolor=palette["fg"],
        )
        style.configure("TButton", padding=6)
        style.map("TButton", background=[("active", palette["select"])])
        style.map("TCheckbutton", background=[("active", palette["bg"])])
        style.configure("TEntry", padding=2)
        style.configure("TCombobox", padding=2, arrowcolor=palette["fg"])
        style.map("TCombobox", fieldbackground=[("readonly", palette["field"])])
        self.option_add("*TCombobox*Listbox.background", palette["field"])
        self.option_add("*TCombobox*Listbox.foreground", palette["fg"])
        self.option_add("*TCombobox*Listbox.selectBackground", palette["select"])
        self.option_add("*TCombobox*Listbox.selectForeground", palette["fg"])

        style.configure(
            "Treeview",
            background=palette["field"],
            fieldbackground=palette["field"],
            foreground=palette["fg"],
            rowheight=26,
            bordercolor=palette["border"],
        )
        style.map(
            "Treeview",
            background=[("selected", palette["select"])],
            foreground=[("selected", palette["fg"])],
        )
        style.configure(
            "Treeview.Heading",
            background=palette["surface"],
            foreground=palette["fg"],
            relief="flat",
            padding=4,
        )
        style.map("Treeview.Heading", background=[("active", palette["select"])])
        style.configure(
            "Vertical.TScrollbar",
            background=palette["surface"],
            troughcolor=palette["bg"],
            arrowcolor=palette["fg"],
            bordercolor=palette["bg"],
            darkcolor=palette["bg"],
            lightcolor=palette["bg"],
        )

        self.tree.tag_configure("enabled", foreground=palette["tag_enabled"])
        self.tree.tag_configure("disabled", foreground=palette["tag_disabled"])
        self.tree.tag_configure("new", foreground=palette["tag_new"])
        self.tree.tag_configure("missing", foreground=palette["tag_missing"])
        self.tree.tag_configure("changed", background=palette["tag_changed"])

        self.log.configure(
            bg=palette["log"],
            fg=palette["fg"],
            insertbackground=palette["fg"],
            selectbackground=palette["select"],
            highlightbackground=palette["border"],
            highlightcolor=palette["border"],
            relief="flat",
        )

    # -- helpers ----------------------------------------------------------

    def _repo(self) -> Path:
        return Path(self.repo_var.get()).expanduser()

    def _log(self, text: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", text + "\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def _run_ctl(self, arguments: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [*ctl_argv(), *arguments],
            capture_output=True, text=True, cwd=self._repo(),
        )

    def _browse_repo(self) -> None:
        chosen = filedialog.askdirectory(initialdir=str(self._repo()))
        if chosen:
            self.repo_var.set(chosen)
            self._refresh_hosts()

    def _refresh_hosts(self) -> None:
        hosts = list_hosts(self._repo())
        self.host_box.configure(values=hosts)
        if hosts and self.host_var.get() not in hosts:
            self.host_var.set(hosts[0])
        if not hosts:
            self.host_var.set("")

    def _selection(self) -> list[int]:
        return [self.tree.index(item) for item in self.tree.selection()]

    # -- loading ----------------------------------------------------------

    def _load_status(self) -> None:
        host = self.host_var.get()
        if not host:
            messagebox.showinfo("modules-ctl", "No host selected.")
            return
        completed = self._run_ctl(["--host", host, "status", "--json"])
        if completed.returncode != 0:
            messagebox.showerror("modules-ctl", completed.stderr.strip() or "status failed")
            return
        self.rows = parse_status(completed.stdout)
        self._redraw()

    def _redraw(self) -> None:
        self.tree.delete(*self.tree.get_children())
        for row in self.rows:
            state_text = (
                f"{row.current} → {row.effective}" if row.changed else row.current
            )
            tags = [row.current]
            if row.changed:
                tags.append("changed")
            self.tree.insert("", "end", values=(state_text, row.kind, row.name), tags=tags)
        self._update_preview()

    # -- editing ----------------------------------------------------------

    def _set_selected(self, enable: bool) -> None:
        wanted = ModuleState.ENABLED.value if enable else ModuleState.DISABLED.value
        for index in self._selection():
            row = self.rows[index]
            if row.current == "missing":
                continue  # nothing to enable/disable; use `prune` instead
            row.desired = None if row.current == wanted else wanted
        self._redraw()

    def _toggle_selected(self) -> None:
        for index in self._selection():
            row = self.rows[index]
            if row.current == "missing":
                continue
            effective = row.effective
            if effective == ModuleState.ENABLED.value:
                row.desired = ModuleState.DISABLED.value
            else:
                row.desired = ModuleState.ENABLED.value
        self._redraw()

    def _revert(self) -> None:
        for row in self.rows:
            row.desired = None
        self._redraw()

    def _update_preview(self) -> None:
        operations = plan_changes(self.rows)
        if not operations:
            self.preview_var.set("No changes.")
            self.apply_button.configure(state="disabled")
            return
        host = self.host_var.get()
        command = " && ".join(
            f"modules-ctl --host {host} {op} {kind} {name}"
            for op, kind, name in operations
        )
        self.preview_var.set(f"{len(operations)} change(s): {command}")
        self.apply_button.configure(state="normal")

    # -- applying ---------------------------------------------------------

    def _apply(self) -> None:
        host = self.host_var.get()
        operations = plan_changes(self.rows)
        if not operations:
            return
        for op, kind, name in operations:
            self._log(f"$ modules-ctl --host {host} {op} {kind} {name}")
            completed = self._run_ctl(["--host", host, op, kind, name])
            if completed.returncode != 0:
                self._log(completed.stderr.strip() or f"{op} {name} failed")
                messagebox.showerror(
                    "modules-ctl", f"'{op} {kind} {name}' failed:\n{completed.stderr.strip()}"
                )
                return
            self._log(completed.stdout.strip())
        self._load_status()


def main() -> int:
    app = ModulePickerApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
