#!/usr/bin/env python3
"""Tauron: a small, beginner-friendly command language and terminal."""

from __future__ import annotations

import ast
import base64
import calendar as calendar_module
import datetime
import hashlib
import json
import math
import os
import platform
import random
import secrets
import signal
import shlex
import shutil
import socket
import statistics
import subprocess
import sys
import time
import urllib.parse
import urllib.error
import urllib.request
import uuid
from pathlib import Path


UNIT_GROUPS = {
    "length": {"m": 1, "km": 1000, "cm": .01, "mm": .001, "um": .000001, "mi": 1609.344, "yd": .9144, "ft": .3048, "in": .0254, "nmi": 1852},
    "mass": {"mg": .000001, "g": .001, "kg": 1, "t": 1000, "oz": .028349523125, "lb": .45359237, "st": 6.35029318},
    "volume": {"ml": .001, "l": 1, "kl": 1000, "tsp": .00492892159, "tbsp": .0147867648, "cup": .236588237, "pt": .473176473, "qt": .946352946, "gal": 3.785411784},
    "time": {"ms": .001, "s": 1, "min": 60, "h": 3600, "d": 86400, "w": 604800},
    "data": {"bit": 1, "byte": 8, "kb": 8000, "mb": 8_000_000, "gb": 8_000_000_000, "kib": 8192, "mib": 8_388_608, "gib": 8_589_934_592},
    "speed": {"mps": 1, "kmh": 1 / 3.6, "mph": .44704, "knot": .514444},
    "area": {"m2": 1, "km2": 1_000_000, "cm2": .0001, "ft2": .09290304, "acre": 4046.8564224, "ha": 10_000},
    "temperature": {"c": 0, "f": 0, "k": 0},
}


COMMAND_INFO = {
    "help": ("Show the complete scrollable command catalog or one command's usage.", "help [command|category]"),
    "calc": ("Safely evaluate basic arithmetic and selected math functions.", "calc <expression>"),
    "convert": ("Convert a value between supported measurement units.", "convert <value> <from-unit> <to-unit>"),
    "percent": ("Calculate a percentage of a number.", "percent <number> <percent>"),
    "factorial": ("Calculate a non-negative integer factorial.", "factorial <integer>"),
    "prime": ("Check if an integer is prime.", "prime <integer>"),
    "fibonacci": ("Print the first N Fibonacci numbers.", "fibonacci <count>"),
    "mean": ("Calculate the arithmetic mean of numbers.", "mean <number>..."),
    "random": ("Pick a random integer in the optional inclusive range.", "random [minimum] [maximum]"),
    "choose": ("Pick one item from the supplied options.", "choose <option> <option>..."),
    "dice": ("Roll dice using optional count and side count.", "dice [count] [sides]"),
    "uuid": ("Generate a random UUID.", "uuid"),
    "password": ("Generate a random password.", "password [length]"),
    "reverse": ("Reverse text.", "reverse <text>"), "upper": ("Convert text to uppercase.", "upper <text>"),
    "lower": ("Convert text to lowercase.", "lower <text>"), "title": ("Convert text to title case.", "title <text>"),
    "slug": ("Create a URL-friendly slug from text.", "slug <text>"), "sorttext": ("Sort text lines.", "sorttext <text>"),
    "unique": ("Remove duplicate words or lines while preserving order.", "unique <text>"),
    "replace": ("Replace text using old and new phrases.", "replace <text> | <old> | <new>"),
    "base64": ("Encode text as Base64.", "base64 <text>"), "unbase64": ("Decode Base64 text.", "unbase64 <encoded>"),
    "urlencode": ("Percent-encode text for a URL.", "urlencode <text>"), "urldecode": ("Decode URL-encoded text.", "urldecode <text>"),
    "jsonfmt": ("Validate and pretty-print JSON.", "jsonfmt <json>"), "hash": ("Compute a SHA-256 digest.", "hash <text>"),
    "sysinfo": ("Show operating system and Python details.", "sysinfo"), "disk": ("Show free and total space for the current volume.", "disk"),
    "hostname": ("Show this computer's network host name.", "hostname"), "dns": ("Look up addresses for a host name.", "dns <hostname>"),
    "calendarview": ("Show a text calendar for a month.", "calendarview [year] [month]"),
    "weekday": ("Show the weekday for an ISO date or today.", "weekday [YYYY-MM-DD]"),
    "timer": ("Run a local countdown timer.", "timer <seconds>"),
    "quiz": ("Show a short built-in practice question.", "quiz"),
}


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
            "calc": self.calc, "convert": self.convert,
            "percent": self.percent, "factorial": self.factorial,
            "prime": self.prime, "fibonacci": self.fibonacci,
            "mean": self.mean, "random": self.random_number,
            "choose": self.choose, "dice": self.dice, "uuid": self.uuid_command,
            "password": self.password,
            "reverse": self.reverse, "upper": self.upper, "lower": self.lower,
            "title": self.title, "slug": self.slug, "sorttext": self.sort_text,
            "unique": self.unique_text, "replace": self.replace_text,
            "base64": self.base64_encode, "unbase64": self.base64_decode,
            "urlencode": self.url_encode, "urldecode": self.url_decode,
            "jsonfmt": self.json_format, "hash": self.hash_text,
            "sysinfo": self.sysinfo, "disk": self.disk_info,
            "hostname": self.hostname, "dns": self.dns_lookup,
            "calendarview": self.calendar_view, "weekday": self.weekday,
            "timer": self.timer, "quiz": self.quiz,
        }
        # Tauron command names are synonyms for explicit built-ins; none invoke a shell.
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
            "calc": "calculate compute math arithmetic",
            "convert": "conversion convertunits unitconvert",
            "percent": "percentage percentof",
            "factorial": "fact",
            "prime": "isprime primality",
            "fibonacci": "fib sequence",
            "mean": "average avg median",
            "random": "rand randint randomnumber",
            "choose": "pick choice",
            "dice": "roll roll_dice",
            "uuid": "guid newuuid",
            "password": "passgen generatepassword",
            "reverse": "rev reverse_text",
            "upper": "uppercase shoutcase",
            "lower": "lowercase",
            "title": "titlecase",
            "slug": "slugify",
            "sorttext": "sortlines",
            "unique": "dedupe uniqueitems",
            "replace": "replacetext",
            "base64": "b64 encode64",
            "unbase64": "decode64",
            "urlencode": "encodeurl",
            "urldecode": "decodeurl",
            "jsonfmt": "jsonformat prettyjson",
            "hash": "sha256 digest",
            "sysinfo": "systeminfo system osinfo",
            "disk": "diskspace storage",
            "hostname": "host computername",
            "dns": "lookuphost resolve",
            "calendarview": "monthcal monthcalendar",
            "weekday": "dayofweek",
            "timer": "countdown studytimer",
            "quiz": "practicequiz",
        }
        self.aliases: dict[str, str] = {}
        for target, names in aliases.items():
            for alias in names.split():
                self.commands[alias] = self.commands[target]
                self.aliases[alias] = target
        self.command_groups: dict[str, str] = {}
        self.conversion_aliases: dict[str, tuple[str, str]] = {}
        self.register_conversion_commands()
        self.assign_command_groups()

    def register_conversion_commands(self) -> None:
        """Register over a thousand real, named unit conversion shortcuts."""
        for group, units in UNIT_GROUPS.items():
            labels = list(units)
            for source in labels:
                for target in labels:
                    if source == target:
                        continue
                    for name in (f"{source}_to_{target}", f"convert_{source}_to_{target}", f"{source}_in_{target}"):
                        def run(args: list[str], a: str = source, b: str = target, shortcut: str = name) -> None:
                            if len(args) != 1:
                                self.out(f"Usage: {shortcut} <number>")
                                return
                            self.convert_value(args[0], a, b)
                        self.commands[name] = run
                        self.aliases[name] = "convert"
                        self.conversion_aliases[name] = (source, target)
                        self.command_groups[name] = "conversions"

    def assign_command_groups(self) -> None:
        groups = {
            "files": "ls cd pwd mkdir touch cat cp mv rm head tail wc find",
            "terminal": "help clear history exit date whoami changelog mod",
            "math": "calc percent factorial prime fibonacci mean random choose dice",
            "text": "reverse upper lower title slug sorttext unique replace base64 unbase64 urlencode urldecode jsonfmt hash",
            "system": "sysinfo disk hostname dns calendarview weekday timer uuid password",
            "study": "quiz",
        }
        for group, names in groups.items():
            for name in names.split():
                self.command_groups[name] = group
        for alias, target in self.aliases.items():
            self.command_groups.setdefault(alias, self.command_groups.get(target, "other"))

    def command_catalog(self) -> list[dict[str, str]]:
        catalog = []
        for name in sorted(self.commands):
            if name in self.aliases:
                continue
            description, usage = COMMAND_INFO.get(name, ("Tauron built-in command.", name))
            catalog.append({"name": name, "description": description, "usage": usage, "category": self.command_groups.get(name, "other")})
        catalog.append({"name": "<unit>_to_<unit>", "description": "Unit-specific conversion commands listed by help conversions.", "usage": "<source>_to_<target> <number>", "category": "conversions"})
        return catalog

    def _number(self, raw: str) -> float:
        return float(raw.replace(",", ""))

    def calc(self, args: list[str]) -> None:
        if not args:
            self.out("Usage: calc <expression> (example: calc 2 * (3 + 4))")
            return
        functions = {"abs": abs, "round": round, "min": min, "max": max, "sqrt": math.sqrt,
                     "sin": math.sin, "cos": math.cos, "tan": math.tan, "log": math.log,
                     "floor": math.floor, "ceil": math.ceil}
        binary = {ast.Add: lambda a,b:a+b, ast.Sub: lambda a,b:a-b, ast.Mult: lambda a,b:a*b,
                  ast.Div: lambda a,b:a/b, ast.FloorDiv: lambda a,b:a//b, ast.Mod: lambda a,b:a%b,
                  ast.Pow: lambda a,b:a**b}
        unary = {ast.UAdd: lambda x:x, ast.USub: lambda x:-x}
        def evaluate(node):
            if isinstance(node, ast.Expression): return evaluate(node.body)
            if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)): return node.value
            if isinstance(node, ast.Name) and node.id in {"pi", "e"}: return getattr(math, node.id)
            if isinstance(node, ast.BinOp) and type(node.op) in binary:
                left, right = evaluate(node.left), evaluate(node.right)
                if isinstance(node.op, ast.Pow) and abs(right) > 1000: raise ValueError("exponent is too large")
                return binary[type(node.op)](left, right)
            if isinstance(node, ast.UnaryOp) and type(node.op) in unary: return unary[type(node.op)](evaluate(node.operand))
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in functions and not node.keywords:
                return functions[node.func.id](*(evaluate(arg) for arg in node.args))
            raise ValueError("only arithmetic, pi, e, and basic math functions are allowed")
        try:
            tree = ast.parse(" ".join(args), mode="eval")
            result = evaluate(tree)
            if isinstance(result, (int, float)) and (not math.isfinite(result) or abs(result) > 1e300): raise ValueError("result is outside the supported range")
            self.out(result)
        except (ValueError, TypeError, ZeroDivisionError, OverflowError, SyntaxError) as exc:
            self.out(f"calc: {exc}")

    def convert_value(self, raw: str, source: str, target: str) -> None:
        source, target = source.lower(), target.lower()
        try: value = self._number(raw)
        except ValueError: self.out("convert: enter a numeric value"); return
        if source in UNIT_GROUPS["temperature"] and target in UNIT_GROUPS["temperature"]:
            to_c = value if source == "c" else (value - 32) * 5 / 9 if source == "f" else value - 273.15
            result = to_c if target == "c" else to_c * 9 / 5 + 32 if target == "f" else to_c + 273.15
        else:
            group = next((units for key, units in UNIT_GROUPS.items() if key != "temperature" and source in units and target in units), None)
            if group is None:
                self.out(f"convert: unsupported unit pair {source} -> {target}"); return
            result = value * group[source] / group[target]
        self.out(f"{value:g} {source} = {result:.10g} {target}")

    def convert(self, args: list[str]) -> None:
        if len(args) != 3:
            self.out("Usage: convert <value> <from-unit> <to-unit>. Use help conversions to browse named conversions.")
            return
        self.convert_value(*args)

    def percent(self, args: list[str]) -> None:
        try:
            if len(args) != 2: raise ValueError("Usage: percent <number> <percent>")
            self.out(self._number(args[0]) * self._number(args[1]) / 100)
        except ValueError as exc: self.out(f"percent: {exc}")

    def factorial(self, args: list[str]) -> None:
        try:
            n = int(args[0])
            if len(args) != 1 or n < 0 or n > 5000: raise ValueError("Usage: factorial <integer 0-5000>")
            self.out(math.factorial(n))
        except (ValueError, IndexError) as exc: self.out(f"factorial: {exc}")

    def prime(self, args: list[str]) -> None:
        try:
            n = int(args[0])
            if len(args) != 1: raise ValueError("Usage: prime <integer>")
            self.out(f"{n} is " + ("prime" if n > 1 and all(n % d for d in range(2, math.isqrt(n) + 1)) else "not prime"))
        except (ValueError, IndexError) as exc: self.out(f"prime: {exc}")

    def fibonacci(self, args: list[str]) -> None:
        try:
            n = int(args[0])
            if len(args) != 1 or not 0 <= n <= 500: raise ValueError("Usage: fibonacci <count 0-500>")
            values, a, b = [], 0, 1
            for _ in range(n): values.append(a); a, b = b, a + b
            self.out(" ".join(map(str, values)))
        except (ValueError, IndexError) as exc: self.out(f"fibonacci: {exc}")

    def mean(self, args: list[str]) -> None:
        try: self.out(statistics.mean(map(self._number, args)) if args else "Usage: mean <number>...")
        except (ValueError, statistics.StatisticsError) as exc: self.out(f"mean: {exc}")

    def random_number(self, args: list[str]) -> None:
        try:
            low, high = (0, 100) if not args else (int(args[0]), int(args[1]) if len(args) > 1 else int(args[0]))
            if len(args) > 2: raise ValueError()
            self.out(random.randint(low, high))
        except ValueError: self.out("Usage: random [minimum] [maximum]")

    def choose(self, args: list[str]) -> None:
        self.out(random.choice(args) if args else "Usage: choose <option> <option>...")

    def dice(self, args: list[str]) -> None:
        try:
            count = int(args[0]) if args else 1; sides = int(args[1]) if len(args) > 1 else 6
            if len(args) > 2 or count < 1 or count > 100 or sides < 2 or sides > 1_000_000: raise ValueError()
            rolls = [random.randint(1, sides) for _ in range(count)]
            self.out(f"Rolls: {', '.join(map(str, rolls))}  Total: {sum(rolls)}")
        except ValueError: self.out("Usage: dice [count 1-100] [sides 2-1000000]")

    def uuid_command(self, args: list[str]) -> None: self.out(uuid.uuid4())
    def password(self, args: list[str]) -> None:
        try:
            length = int(args[0]) if args else 20
            if len(args) > 1 or not 8 <= length <= 128: raise ValueError()
            self.out("".join(secrets.choice("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*-_+") for _ in range(length)))
        except ValueError: self.out("Usage: password [length 8-128]")

    def _text(self, args: list[str]) -> str: return " ".join(args)
    def reverse(self, args: list[str]) -> None: self.out(self._text(args)[::-1])
    def upper(self, args: list[str]) -> None: self.out(self._text(args).upper())
    def lower(self, args: list[str]) -> None: self.out(self._text(args).lower())
    def title(self, args: list[str]) -> None: self.out(self._text(args).title())
    def slug(self, args: list[str]) -> None:
        import re
        self.out(re.sub(r"[^a-z0-9]+", "-", self._text(args).lower()).strip("-"))
    def sort_text(self, args: list[str]) -> None: self.out("\n".join(sorted(self._text(args).splitlines(), key=str.casefold)))
    def unique_text(self, args: list[str]) -> None:
        seen = set(); values = []
        for item in self._text(args).splitlines() if "\n" in self._text(args) else args:
            key = item.casefold()
            if key not in seen: seen.add(key); values.append(item)
        self.out("\n".join(values))
    def replace_text(self, args: list[str]) -> None:
        parts = self._text(args).split("|", 2)
        if len(parts) != 3: self.out("Usage: replace <text> | <old> | <new>"); return
        self.out(parts[0].replace(parts[1], parts[2]))
    def base64_encode(self, args: list[str]) -> None: self.out(base64.b64encode(self._text(args).encode()).decode())
    def base64_decode(self, args: list[str]) -> None:
        try: self.out(base64.b64decode(self._text(args), validate=True).decode("utf-8"))
        except (ValueError, UnicodeError) as exc: self.out(f"unbase64: {exc}")
    def url_encode(self, args: list[str]) -> None: self.out(urllib.parse.quote(self._text(args), safe=""))
    def url_decode(self, args: list[str]) -> None: self.out(urllib.parse.unquote(self._text(args)))
    def json_format(self, args: list[str]) -> None:
        try: self.out(json.dumps(json.loads(self._text(args)), indent=2, ensure_ascii=False))
        except json.JSONDecodeError as exc: self.out(f"jsonfmt: {exc}")
    def hash_text(self, args: list[str]) -> None: self.out(hashlib.sha256(self._text(args).encode()).hexdigest())
    def sysinfo(self, args: list[str]) -> None: self.out(f"System: {platform.platform()}\nPython: {platform.python_version()}\nMachine: {platform.machine()}")
    def disk_info(self, args: list[str]) -> None:
        usage = shutil.disk_usage(self.cwd)
        self.out(f"Location: {self.cwd}\nTotal: {usage.total:,} bytes\nUsed: {usage.used:,} bytes\nFree: {usage.free:,} bytes")
    def hostname(self, args: list[str]) -> None: self.out(socket.gethostname())
    def dns_lookup(self, args: list[str]) -> None:
        if len(args) != 1: self.out("Usage: dns <hostname>"); return
        try: self.out("\n".join(sorted({item[4][0] for item in socket.getaddrinfo(args[0], None)})))
        except OSError as exc: self.out(f"dns: {exc}")
    def calendar_view(self, args: list[str]) -> None:
        today = datetime.date.today()
        try:
            year, month = (int(args[0]), int(args[1])) if len(args) == 2 else (today.year, today.month) if not args else (today.year, int(args[0]))
            self.out(calendar_module.month(year, month))
        except (ValueError, calendar_module.IllegalMonthError): self.out("Usage: calendarview [year] [month]")
    def weekday(self, args: list[str]) -> None:
        try: day = datetime.date.fromisoformat(args[0]) if args else datetime.date.today(); self.out(day.strftime("%A, %Y-%m-%d"))
        except ValueError: self.out("Usage: weekday [YYYY-MM-DD]")
    def timer(self, args: list[str]) -> None:
        try:
            seconds = int(args[0])
            if len(args) != 1 or not 1 <= seconds <= 3600: raise ValueError()
            self.out(f"Timer started: {seconds} seconds")
            time.sleep(seconds)
            self.out("Timer complete.")
        except (ValueError, IndexError): self.out("Usage: timer <seconds 1-3600>")
    def quiz(self, args: list[str]) -> None:
        prompts = ["Math: What is 12 × 8? Answer: 96.", "Science: What gas do plants absorb during photosynthesis? Answer: Carbon dioxide.", "Geography: What is the largest ocean on Earth? Answer: The Pacific Ocean."]
        self.out(random.choice(prompts))

    def path(self, raw: str) -> Path:
        p = Path(os.path.expanduser(raw))
        return (self.cwd / p).resolve() if not p.is_absolute() else p.resolve()

    def out(self, value: object = "") -> None:
        print(value)

    def help(self, args: list[str]) -> None:
        names = sorted(self.commands)
        if not args or args[0] in ("list", "all"):
            self.out(f"Tauron commands ({len(names)} names, {len(self.aliases)} shortcuts). Scroll to browse the complete list.")
            self.out("Categories: files, terminal, math, text, system, study, conversions. Use help <category> to filter.")
            for name in names:
                target = self.aliases.get(name)
                self.out(f"  {name}" + (f"  (same as {target})" if target else ""))
            self.out("Use help <command> for usage.")
            return
        if args[0] in {"files", "terminal", "math", "text", "system", "study", "conversions"}:
            group = args[0]
            matched = [name for name in names if self.command_groups.get(name) == group]
            self.out(f"Tauron {group} commands ({len(matched)}):")
            for name in matched: self.out(f"  {name}")
            return
        if args[0] in self.conversion_aliases:
            source, target = self.conversion_aliases[args[0]]
            self.out(f"Usage: {args[0]} <number>  — convert {source} to {target}")
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
            if name in COMMAND_INFO:
                description, command_usage = COMMAND_INFO[name]
                self.out(f"{description}\nUsage: {command_usage}")
            elif name in usage:
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
        config_path = Path(__file__).resolve().parent / "update-config.json"
        try:
            config = json.loads(config_path.read_text(encoding="utf-8"))
            repo = config.get("github_repository", "").strip()
            owner, separator, name = repo.partition("/")
            if not separator or not owner or not name or "/" in name or not all(part.replace("-", "").replace("_", "").replace(".", "").isalnum() for part in (owner, name)):
                raise ValueError("invalid GitHub repository setting")
            request = urllib.request.Request(
                f"https://raw.githubusercontent.com/{owner}/{name}/main/CHANGELOG.md",
                headers={"User-Agent": "Tauron-Changelog", "Accept": "text/plain"},
            )
            with urllib.request.urlopen(request, timeout=4) as response:
                content = response.read(200_001)
            if len(content) > 200_000:
                raise ValueError("remote changelog is unexpectedly large")
            live_text = content.decode("utf-8").strip()
            if not live_text:
                raise ValueError("remote changelog is empty")
            self.out("Tauron Changelog — live from GitHub\n")
            self.out(live_text)
        except (OSError, ValueError, UnicodeError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as remote_error:
            try:
                local_text = path.read_text(encoding="utf-8").rstrip()
                self.out("Tauron Changelog — bundled copy (GitHub is unavailable)\n")
                self.out(local_text)
            except OSError as local_error:
                self.out(f"changelog: could not load live or bundled notes ({remote_error}; {local_error})")

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
    if "--json-commands" in sys.argv[1:]:
        print(json.dumps(Tauron().command_catalog(), ensure_ascii=False))
    else:
        Tauron().run()
