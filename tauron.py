#!/usr/bin/env python3
"""Tauron: a small, beginner-friendly command language and terminal."""

from __future__ import annotations

import datetime
import os
import signal
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path


class Tauron:
    def __init__(self) -> None:
        self.cwd = Path.cwd()
        self.history: list[str] = []
        self.running = True
        self.mods: dict[str, dict[str, tuple[str, list[str]]]] = {}
        self.commands = {
            "help": self.help, "clear": self.clear, "pwd": self.pwd,
            "ls": self.ls, "cd": self.cd, "mkdir": self.mkdir,
            "touch": self.touch, "cat": self.cat, "echo": self.echo,
            "cp": self.cp, "mv": self.mv, "rm": self.rm,
            "head": self.head, "tail": self.tail, "wc": self.wc,
            "find": self.find, "date": self.date, "whoami": self.whoami,
            "history": self.show_history, "exit": self.exit,
            "mod": self.mod,
            "changelog": self.changelog,
        }
        # Tauron has 100 extra built-in names, grouped around the core commands.
        # These are convenient synonyms, so they behave consistently with the
        # original command and do not invoke the host shell.
        aliases = {
            "ls": "dir list files showfiles files folder contents browse showdir walkdir",
            "cd": "chdir go enter openfolder changefolder goto moveinto switchdir",
            "pwd": "whereami currentdir currentfolder location here path cwd",
            "mkdir": "makedir newdir newfolder createdir createfolder makefolder",
            "touch": "newfile makefile createfile addfile blankfile createnewfile",
            "cat": "type read showfile displayfile viewfile printfile readfile",
            "echo": "say print write text speak output",
            "cp": "copy duplicate clone replicate copyfile",
            "mv": "move rename relocate movefile",
            "rm": "del delete remove erase trash unlink",
            "head": "first beginning startof",
            "tail": "last ending endof",
            "wc": "count countfile stats filestats",
            "find": "search locate lookup",
            "date": "now time today timestamp clock calendar",
            "whoami": "user username account currentuser",
            "history": "commands previous recent",
            "clear": "cls wipe screen",
            "help": "manual commands commandlist",
            "exit": "quit bye logout stop close",
        }
        self.aliases: dict[str, str] = {}
        for target, names in aliases.items():
            for alias in names.split():
                self.commands[alias] = self.commands[target]
                self.aliases[alias] = target

    def path(self, raw: str) -> Path:
        p = Path(os.path.expanduser(raw))
        return (self.cwd / p).resolve() if not p.is_absolute() else p.resolve()

    def out(self, value: object = "") -> None:
        print(value)

    def help(self, args: list[str]) -> None:
        names = sorted(self.commands)
        if not args or args[0] in ("list", "all"):
            self.out(f"Tauron commands ({len(names)} names, {len(self.aliases)} shortcuts):")
            for name in names:
                target = self.aliases.get(name)
                self.out(f"  {name}" + (f"  (same as {target})" if target else ""))
            self.out("Use help <command> for usage. Scroll up in Terminal to browse the full list.")
            return
        usage = {
            "ls": "ls [path]", "cd": "cd [path]", "mkdir": "mkdir <dir>...",
            "touch": "touch <file>...", "cat": "cat <file>...", "echo": "echo [text...]",
            "cp": "cp <source> <destination>", "mv": "mv <source> <destination>",
            "rm": "rm <file>...", "head": "head [-n count] <file>",
            "tail": "tail [-n count] <file>", "wc": "wc <file>...",
            "find": "find [path] [name-pattern]", "history": "history",
            "exit": "exit", "mod": "mod load <file.tau> | mod list | mod unload <name>",
            "changelog": "changelog",
        }
        if args:
            name = args[0]
            name = self.aliases.get(name, name)
            if name in usage:
                self.out(f"Usage: {usage[name]}")
            elif name in self.commands:
                self.out(f"{name}: Tauron built-in command")
            else:
                self.out(f"help: unknown command: {name}")

    def clear(self, args: list[str]) -> None:
        print("\033[2J\033[H", end="", flush=True)

    def pwd(self, args: list[str]) -> None:
        self.out(self.cwd)

    def ls(self, args: list[str]) -> None:
        p = self.path(args[0]) if args else self.cwd
        try:
            if p.is_dir():
                for child in sorted(p.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
                    self.out(child.name + ("/" if child.is_dir() else ""))
            elif p.exists():
                self.out(p.name)
            else:
                raise FileNotFoundError(p)
        except OSError as e:
            self.out(f"ls: {e}")

    def cd(self, args: list[str]) -> None:
        p = self.path(args[0]) if args else Path.home()
        if p.is_dir():
            self.cwd = p
        else:
            self.out(f"cd: not a directory: {p}")

    def mkdir(self, args: list[str]) -> None:
        if not args:
            self.out("Usage: mkdir <dir>..."); return
        for name in args:
            try: self.path(name).mkdir()
            except OSError as e: self.out(f"mkdir: {e}")

    def touch(self, args: list[str]) -> None:
        if not args:
            self.out("Usage: touch <file>..."); return
        for name in args:
            try: self.path(name).touch(exist_ok=True)
            except OSError as e: self.out(f"touch: {e}")

    def cat(self, args: list[str]) -> None:
        if not args: self.out("Usage: cat <file>..."); return
        for name in args:
            try: print(self.path(name).read_text(), end="")
            except (OSError, UnicodeError) as e: self.out(f"cat: {name}: {e}")

    def echo(self, args: list[str]) -> None:
        self.out(" ".join(args))

    def cp(self, args: list[str]) -> None:
        if len(args) != 2: self.out("Usage: cp <source> <destination>"); return
        try:
            src, dst = map(self.path, args)
            if src.is_dir(): shutil.copytree(src, dst, dirs_exist_ok=True)
            else: shutil.copy2(src, dst)
        except OSError as e: self.out(f"cp: {e}")

    def mv(self, args: list[str]) -> None:
        if len(args) != 2: self.out("Usage: mv <source> <destination>"); return
        try: shutil.move(str(self.path(args[0])), str(self.path(args[1])))
        except OSError as e: self.out(f"mv: {e}")

    def rm(self, args: list[str]) -> None:
        if not args: self.out("Usage: rm <file>..."); return
        for name in args:
            p = self.path(name)
            try:
                if p.is_dir(): self.out(f"rm: {p}: is a directory (directories are not removed)")
                else: p.unlink()
            except OSError as e: self.out(f"rm: {e}")

    def line_command(self, args: list[str], from_end: bool) -> None:
        count = 10
        if len(args) >= 2 and args[0] == "-n":
            try: count = max(0, int(args[1]))
            except ValueError: self.out("line count must be a number"); return
            args = args[2:]
        if len(args) != 1: self.out("Usage: head|tail [-n count] <file>"); return
        try:
            lines = self.path(args[0]).read_text().splitlines(keepends=True)
            print("".join(lines[-count:] if from_end and count else lines[:count]), end="")
        except (OSError, UnicodeError) as e: self.out(f"file: {e}")

    def head(self, args: list[str]) -> None: self.line_command(args, False)
    def tail(self, args: list[str]) -> None: self.line_command(args, True)

    def wc(self, args: list[str]) -> None:
        if not args: self.out("Usage: wc <file>..."); return
        for name in args:
            try:
                text = self.path(name).read_text()
                self.out(f"{len(text.splitlines())} lines, {len(text.split())} words, {len(text)} characters  {name}")
            except (OSError, UnicodeError) as e: self.out(f"wc: {name}: {e}")

    def find(self, args: list[str]) -> None:
        root = self.path(args[0]) if args else self.cwd
        pattern = args[1] if len(args) > 1 else "*"
        if len(args) > 2: self.out("Usage: find [path] [name-pattern]"); return
        try:
            for p in root.rglob(pattern): self.out(p.relative_to(self.cwd) if p.is_relative_to(self.cwd) else p)
        except OSError as e: self.out(f"find: {e}")

    def date(self, args: list[str]) -> None:
        self.out(datetime.datetime.now().astimezone().strftime("%a %b %d %H:%M:%S %Z %Y"))

    def whoami(self, args: list[str]) -> None:
        self.out(os.getenv("USER", "unknown"))

    def show_history(self, args: list[str]) -> None:
        for i, command in enumerate(self.history, 1): self.out(f"{i}  {command}")

    def changelog(self, args: list[str]) -> None:
        path = Path(__file__).resolve().parent / "CHANGELOG.md"
        try:
            self.out(path.read_text(encoding="utf-8").rstrip())
        except OSError as e:
            self.out(f"changelog: {e}")

    def mod(self, args: list[str]) -> None:
        if not args or args[0] == "help":
            self.out("Tauron Mod Language: mod load <file.tau> | mod list | mod unload <name>")
            return
        action = args[0]
        if action == "list":
            if not self.mods:
                self.out("No mods loaded."); return
            for name, commands in self.mods.items():
                self.out(f"{name}: {', '.join(commands)}")
            return
        if action == "unload" and len(args) == 2:
            name = args[1]
            if name not in self.mods:
                self.out(f"mod: no loaded mod named {name}"); return
            for command in self.mods[name]:
                self.commands.pop(command, None)
            del self.mods[name]
            self.out(f"Unloaded mod {name}.")
            return
        if action != "load" or len(args) != 2:
            self.out("Usage: mod load <file.tau> | mod list | mod unload <name>"); return
        path = self.path(args[1])
        try:
            text = path.read_text(encoding="utf-8")
            parsed = self.parse_mod(text)
            name = parsed[0]
            if name in self.mods:
                self.out(f"mod: {name} is already loaded; unload it first to replace it."); return
            conflicts = set(parsed[1]) & set(self.commands)
            if conflicts:
                self.out("mod: command name already exists: " + ", ".join(sorted(conflicts))); return
            self.mods[name] = parsed[1]
            for command_name, (description, body) in parsed[1].items():
                self.commands[command_name] = self.make_mod_command(name, command_name, description, body)
            self.out(f"Loaded mod {name} with {len(parsed[1])} command(s).")
        except (OSError, ValueError) as e:
            self.out(f"mod: {e}")

    def parse_mod(self, source: str) -> tuple[str, dict[str, tuple[str, list[str]]]]:
        """Parse the deliberately small, non-executable .tau mod format."""
        mod_name: str | None = None
        commands: dict[str, tuple[str, list[str]]] = {}
        current: tuple[str, str, list[str]] | None = None
        for line_no, raw in enumerate(source.splitlines(), 1):
            stripped = raw.strip()
            if not stripped or stripped.startswith("#"):
                continue
            try:
                parts = shlex.split(stripped)
            except ValueError as e:
                raise ValueError(f"line {line_no}: {e}") from e
            if not parts:
                continue
            if current is None:
                if parts[0] == "mod" and len(parts) == 2 and mod_name is None:
                    mod_name = parts[1]
                elif parts[0] == "command" and len(parts) >= 2 and mod_name:
                    if not parts[1].isidentifier():
                        raise ValueError(f"line {line_no}: command name must be a simple identifier")
                    if parts[1] in commands:
                        raise ValueError(f"line {line_no}: duplicate command {parts[1]}")
                    current = (parts[1], " ".join(parts[2:]) or "A Tauron mod command", [])
                else:
                    raise ValueError(f"line {line_no}: expected 'mod NAME' or 'command NAME [description]'")
            elif parts[0] == "end":
                commands[current[0]] = (current[1], current[2])
                current = None
            elif parts[0] in {"say", "print", "help", "set", "show", "if", "else", "repeat", "done"}:
                current[2].append(stripped)
            else:
                raise ValueError(f"line {line_no}: unknown mod instruction {parts[0]!r}")
        if current:
            raise ValueError("unfinished command block; add 'end'")
        if not mod_name:
            raise ValueError("missing 'mod NAME' declaration")
        if not commands:
            raise ValueError("mod must define at least one command")
        return mod_name, commands

    def make_mod_command(self, mod_name: str, command_name: str, description: str, body: list[str]):
        def run(args: list[str]) -> None:
            variables = {"args": " ".join(args), "mod": mod_name, "command": command_name}
            self.execute_mod_block(body, args, variables)
        return run

    def execute_mod_block(self, lines: list[str], args: list[str], variables: dict[str, str]) -> None:
        # Blocks are interpreted with explicit instructions; Python/eval is never run.
        index = 0
        while index < len(lines):
            try:
                parts = shlex.split(lines[index])
                op = parts[0]
                if op in ("say", "print", "help"):
                    message = " ".join(parts[1:])
                    for key, value in variables.items():
                        message = message.replace("{" + key + "}", value)
                    for n, value in enumerate(args, 1):
                        message = message.replace("{" + str(n) + "}", value)
                    if op == "help": self.out(message)
                    else: self.out(message)
                elif op == "set" and len(parts) >= 3:
                    variables[parts[1]] = " ".join(parts[2:])
                elif op == "show" and len(parts) == 2:
                    self.out(variables.get(parts[1], ""))
                elif op == "if" and len(parts) >= 3:
                    key, expected = parts[1], " ".join(parts[2:])
                    actual = variables.get(key, args[int(key) - 1] if key.isdigit() and int(key) <= len(args) else "")
                    if actual != expected:
                        index += 1
                        while index < len(lines) and lines[index].strip() != "else": index += 1
                elif op == "else":
                    while index < len(lines) and lines[index].strip() != "done": index += 1
                elif op == "repeat" and len(parts) == 2:
                    count = max(0, min(100, int(parts[1])))
                    end = index + 1
                    while end < len(lines) and lines[end].strip() != "done": end += 1
                    self.execute_mod_block(lines[index + 1:end], args, variables)
                    for _ in range(count - 1): self.execute_mod_block(lines[index + 1:end], args, variables)
                    index = end
                elif op == "done":
                    pass
                else:
                    self.out(f"mod runtime: invalid instruction: {lines[index]}")
            except (ValueError, IndexError) as e:
                self.out(f"mod runtime: {e}")
            index += 1

    def exit(self, args: list[str]) -> None:
        self.running = False

    def startup(self) -> None:
        """Show a short cyber-console boot screen before the prompt."""
        if os.getenv("TAURON_GUI") == "1":
            # Older native app builds do not know how to restart after their
            # updater replaces the app bundle. The updated command engine is
            # launched immediately afterward, so hand off to the new app here.
            if not os.getenv("TAURON_APP_VERSION"):
                app = Path.home() / "Applications" / "Tauron.app"
                if app.exists():
                    try:
                        subprocess.Popen(["/usr/bin/open", "-n", str(app)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        os.kill(os.getppid(), signal.SIGTERM)
                        self.running = False
                        return
                    except OSError:
                        pass
            self.out("Tauron command engine ready. Type 'help' to list commands.")
            return
        green, dim, reset, cyan = "\033[92m", "\033[2m", "\033[0m", "\033[96m"
        try:
            version = (Path(__file__).resolve().parent / "VERSION").read_text(encoding="utf-8").strip()
        except OSError:
            version = "0.1.0"
        self.out("\033[2J\033[H")
        self.out(f"{green}╔══════════════════════════════════════════════════════════════╗")
        self.out("║  ████████╗ █████╗ ██╗   ██╗██████╗  ██████╗ ███╗   ██╗       ║")
        self.out("║  ╚══██╔══╝██╔══██╗██║   ██║██╔══██╗██╔═══██╗████╗  ██║       ║")
        self.out("║     ██║   ███████║██║   ██║██████╔╝██║   ██║██╔██╗ ██║       ║")
        self.out("║     ██║   ██╔══██║██║   ██║██╔══██╗██║   ██║██║╚██╗██║       ║")
        self.out("║     ██║   ██║  ██║╚██████╔╝██║  ██║╚██████╔╝██║ ╚████║       ║")
        self.out("║     ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝       ║")
        self.out(f"╚══════════════════════════════════════════════════════════════╝{reset}")
        self.out(f"{cyan}             TAURON TERMINAL  //  VERSION {version}{reset}\n")
        if sys.stdout.isatty():
            lines = ["Starting Tauron core", f"Loading Tauron commands [{len(self.commands)}]", "Linking workspace", "Console ready"]
            for label in lines:
                self.out(f"{dim}[boot]{reset} {label} ... ",)
                time.sleep(0.12)
                self.out(f"{green}OK{reset}")
            self.out(f"{green}█{reset}" * 36 + "\n")
        self.out("Type 'help' to list commands. Type 'exit' to leave Tauron.\n")

    def run_line(self, line: str) -> None:
        try: parts = shlex.split(line)
        except ValueError as e: self.out(f"Tauron: {e}"); return
        if not parts: return
        name, args = parts[0], parts[1:]
        command = self.commands.get(name)
        if command is None: self.out(f"Tauron: unknown command: {name}. Try 'help'."); return
        command(args)

    def run(self) -> None:
        self.startup()
        while self.running:
            try: line = input(f"tauron:{self.cwd.name or '/'} $ ")
            except EOFError: break
            except KeyboardInterrupt: self.out(); continue
            if line.strip(): self.history.append(line)
            self.run_line(line)


if __name__ == "__main__":
    Tauron().run()
