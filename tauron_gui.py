#!/usr/bin/env python3
"""Independent desktop interface for the Tauron command engine."""

from __future__ import annotations

import shlex
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog

from tauron import Tauron


class TextOutput:
    def __init__(self, app: "TauronWindow") -> None:
        self.app = app

    def write(self, value: str) -> int:
        if value:
            self.app.append_output(value)
        return len(value)

    def flush(self) -> None:
        pass

    def isatty(self) -> bool:
        return False


class TauronWindow:
    BG = "#08120f"
    PANEL = "#101d19"
    GREEN = "#9df5bd"
    MUTED = "#91aa9b"
    WHITE = "#edf7f0"

    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("Tauron")
        self.root.geometry("1060x720")
        self.root.minsize(760, 500)
        self.root.configure(bg=self.BG)
        self.engine = Tauron()
        self.engine.cwd = Path.home()
        self.command_history: list[str] = []
        self.history_index = 0
        self.file_entries: list[Path] = []
        self.original_stdout = sys.stdout
        sys.stdout = TextOutput(self)  # Route the shared command engine to this window.
        self.engine.commands["clear"] = self.clear_output
        for alias, target in self.engine.aliases.items():
            if target == "clear":
                self.engine.commands[alias] = self.clear_output
        self.build()
        self.write_welcome()
        self.refresh_files()
        self.root.protocol("WM_DELETE_WINDOW", self.close)

    def build(self) -> None:
        header = tk.Frame(self.root, bg=self.PANEL, padx=22, pady=14)
        header.pack(fill="x")
        brand = tk.Label(header, text="TAURON", bg=self.PANEL, fg=self.GREEN,
                         font=("Menlo", 19, "bold"))
        brand.pack(side="left")
        tk.Label(header, text="  DESKTOP TERMINAL", bg=self.PANEL, fg=self.MUTED,
                 font=("Menlo", 10)).pack(side="left", pady=(5, 0))
        tk.Label(header, text="●  MAC FILES · DIRECT", bg=self.PANEL, fg=self.GREEN,
                 font=("Menlo", 9, "bold")).pack(side="right", pady=(5, 0))

        body = tk.Frame(self.root, bg=self.BG)
        body.pack(fill="both", expand=True, padx=16, pady=16)
        sidebar = tk.Frame(body, bg=self.PANEL, width=260, padx=12, pady=12)
        sidebar.pack(side="left", fill="y")
        sidebar.pack_propagate(False)
        tk.Label(sidebar, text="MAC FILES", bg=self.PANEL, fg=self.GREEN,
                 font=("Menlo", 10, "bold")).pack(anchor="w")
        self.path_label = tk.Label(sidebar, text="", bg=self.PANEL, fg=self.MUTED,
                                   font=("Menlo", 9), wraplength=230, justify="left")
        self.path_label.pack(anchor="w", fill="x", pady=(8, 10))
        self.file_list = tk.Listbox(sidebar, bg=self.BG, fg=self.WHITE,
                                    selectbackground="#20573a", selectforeground="white",
                                    font=("Menlo", 10), relief="flat", highlightthickness=0,
                                    activestyle="none")
        self.file_list.pack(fill="both", expand=True)
        self.file_list.bind("<Double-Button-1>", self.open_selected)
        tk.Button(sidebar, text="Choose folder…", command=self.choose_folder,
                  bg="#173827", fg=self.GREEN, activebackground="#20573a",
                  activeforeground="white", relief="flat", font=("Menlo", 10),
                  padx=8, pady=8).pack(fill="x", pady=(10, 0))

        terminal = tk.Frame(body, bg=self.BG)
        terminal.pack(side="left", fill="both", expand=True, padx=(14, 0))
        self.output = tk.Text(terminal, bg=self.BG, fg=self.GREEN, insertbackground=self.GREEN,
                              font=("Menlo", 11), relief="flat", wrap="word",
                              padx=16, pady=16, spacing1=2, state="disabled")
        self.output.pack(fill="both", expand=True)
        self.output.tag_configure("system", foreground=self.MUTED)
        self.output.tag_configure("command", foreground=self.WHITE)
        self.output.tag_configure("error", foreground="#ff8585")

        input_row = tk.Frame(terminal, bg=self.PANEL, padx=12, pady=10)
        input_row.pack(fill="x", pady=(12, 0))
        self.prompt = tk.Label(input_row, text="", bg=self.PANEL, fg=self.GREEN,
                               font=("Menlo", 10, "bold"))
        self.prompt.pack(side="left")
        self.entry = tk.Entry(input_row, bg=self.PANEL, fg=self.WHITE, insertbackground=self.GREEN,
                              font=("Menlo", 11), relief="flat", borderwidth=0)
        self.entry.pack(side="left", fill="x", expand=True, padx=(8, 0))
        self.entry.bind("<Return>", self.submit)
        self.entry.bind("<Up>", self.previous_command)
        self.entry.bind("<Down>", self.next_command)
        self.entry.focus_set()
        self.update_prompt()

        footer = tk.Label(self.root,
                          text="Commands work directly in the selected Mac folder. Type help to browse commands.",
                          bg=self.BG, fg=self.MUTED, font=("Menlo", 9), anchor="w", padx=18, pady=7)
        footer.pack(fill="x")

    def append_output(self, value: str) -> None:
        self.output.configure(state="normal")
        self.output.insert("end", value)
        self.output.see("end")
        self.output.configure(state="disabled")

    def write_welcome(self) -> None:
        version_file = Path(__file__).resolve().parent / "VERSION"
        version = version_file.read_text(encoding="utf-8").strip() if version_file.exists() else "0.2.0"
        self.append_output(f"TAURON DESKTOP  //  VERSION {version}\n")
        self.append_output("──────────────────────────────────────────────────────────\n")
        self.append_output("Choose a Mac folder on the left, or type help to get started.\n")
        self.append_output("Your commands read and change the files in that folder directly.\n\n")

    def update_prompt(self) -> None:
        self.prompt.configure(text=f"tauron:{self.engine.cwd.name or '/'} $ ")
        self.path_label.configure(text=str(self.engine.cwd))

    def submit(self, _event: object = None) -> str:
        line = self.entry.get().strip()
        self.entry.delete(0, "end")
        if not line:
            return "break"
        self.command_history.append(line)
        self.history_index = len(self.command_history)
        self.append_output(f"tauron:{self.engine.cwd.name or '/'} $ {line}\n")
        self.engine.history.append(line)
        self.engine.run_line(line)
        self.update_prompt()
        self.refresh_files()
        command_name = line.split(maxsplit=1)[0]
        if command_name == "exit" or self.engine.aliases.get(command_name) == "exit":
            self.root.after(100, self.close)
        return "break"

    def previous_command(self, _event: object = None) -> str:
        if self.command_history:
            self.history_index = max(0, self.history_index - 1)
            self.entry.delete(0, "end")
            self.entry.insert(0, self.command_history[self.history_index])
        return "break"

    def next_command(self, _event: object = None) -> str:
        if self.command_history:
            self.history_index = min(len(self.command_history), self.history_index + 1)
            value = self.command_history[self.history_index] if self.history_index < len(self.command_history) else ""
            self.entry.delete(0, "end")
            self.entry.insert(0, value)
        return "break"

    def clear_output(self, _args: list[str]) -> None:
        self.output.configure(state="normal")
        self.output.delete("1.0", "end")
        self.output.configure(state="disabled")

    def choose_folder(self) -> None:
        selected = filedialog.askdirectory(initialdir=str(self.engine.cwd), title="Choose Tauron working folder")
        if selected:
            self.engine.cwd = Path(selected).resolve()
            self.append_output(f"\nWorking folder: {self.engine.cwd}\n")
            self.update_prompt()
            self.refresh_files()

    def refresh_files(self) -> None:
        self.file_list.delete(0, "end")
        self.file_entries = []
        try:
            children = sorted(self.engine.cwd.iterdir(), key=lambda p: (not p.is_dir(), p.name.casefold()))
        except OSError as error:
            self.append_output(f"File browser: {error}\n")
            return
        for child in children:
            if child.name.startswith("."):
                continue
            self.file_entries.append(child)
            marker = "▸  " if child.is_dir() else "   "
            suffix = "/" if child.is_dir() else ""
            self.file_list.insert("end", f"{marker}{child.name}{suffix}")

    def open_selected(self, _event: object = None) -> None:
        selected = self.file_list.curselection()
        if not selected:
            return
        path = self.file_entries[selected[0]]
        if path.is_dir():
            self.engine.cwd = path
            self.update_prompt()
            self.refresh_files()
            self.append_output(f"\nOpened folder: {path}\n")
        else:
            self.append_output(f"tauron:{self.engine.cwd.name or '/'} $ cat {shlex.quote(path.name)}\n")
            self.engine.run_line("cat " + shlex.quote(path.name))
            self.append_output("\n")

    def close(self) -> None:
        sys.stdout = self.original_stdout
        self.root.destroy()


if __name__ == "__main__":
    TauronWindow().root.mainloop()
