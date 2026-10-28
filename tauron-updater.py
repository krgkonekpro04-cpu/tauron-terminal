#!/usr/bin/env python3
"""Optional GitHub Releases updater for installed Tauron copies."""
from __future__ import annotations

import json
import ctypes
import os
import signal
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def running_native_app(pid: int) -> bool:
    """Identify older Tauron app processes that cannot handle the update exit code."""
    try:
        libproc = ctypes.CDLL("/usr/lib/libproc.dylib")
        proc_pidpath = libproc.proc_pidpath
        proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
        proc_pidpath.restype = ctypes.c_int
        buffer = ctypes.create_string_buffer(4096)
        if proc_pidpath(pid, buffer, len(buffer)) <= 0:
            return False
        path = os.fsdecode(buffer.value)
        return path.endswith(".app/Contents/MacOS/Tauron")
    except (AttributeError, OSError):
        return False


def handoff_older_app() -> None:
    """Open the updated bundle and stop a pre-0.4.1 native parent process."""
    parent = os.getppid()
    if os.environ.get("TAURON_MANAGED_RELAUNCH") == "1" or not running_native_app(parent):
        return
    app = Path.home() / "Applications" / "Tauron.app"
    try:
        subprocess.Popen(["/usr/bin/open", "-n", str(app)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.kill(parent, signal.SIGTERM)
    except OSError:
        # Keep the old app alive if the new app could not be launched.
        return


def version_key(value: str) -> tuple[int, ...]:
    try:
        return tuple(int(piece) for piece in value.lstrip("v").split(".") if piece.isdigit())
    except ValueError:
        return ()


def main() -> bool:
    try:
        config = json.loads((ROOT / "update-config.json").read_text(encoding="utf-8"))
        repo = config.get("github_repository", "").strip()
        if not repo or "/" not in repo:
            return False
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/releases/latest",
            headers={"Accept": "application/vnd.github+json", "User-Agent": "Tauron-Updater"},
        )
        with urllib.request.urlopen(request, timeout=2.5) as response:
            release = json.load(response)
        latest = release.get("tag_name", "").lstrip("v")
        current = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        if not latest or version_key(latest) <= version_key(current):
            return False
        asset = next((item for item in release.get("assets", []) if item.get("name") == "tauron-macos.zip"), None)
        if not asset:
            return False
        req = urllib.request.Request(asset["browser_download_url"], headers={"User-Agent": "Tauron-Updater"})
        with urllib.request.urlopen(req, timeout=15) as response:
            payload = response.read(20_000_000)
        with tempfile.TemporaryDirectory(prefix="tauron-update-") as temp:
            archive = Path(temp) / "update.zip"
            archive.write_bytes(payload)
            stage = Path(temp) / "stage"
            stage.mkdir()
            with zipfile.ZipFile(archive) as zf:
                for info in zf.infolist():
                    target = (stage / info.filename).resolve()
                    if target != stage and stage not in target.parents:
                        raise ValueError("unsafe path in update archive")
                zf.extractall(stage)
            # Preserve user settings and mod files; only replace packaged program files.
            for name in ("tauron.py", "tauron_gui.py", "Tauron.command", "tauron-updater.py", "VERSION", "CHANGELOG.md", "examples", "Tauron.app"):
                source = stage / name
                if not source.exists():
                    continue
                target = ROOT / name
                if name == "Tauron.app":
                    target = Path.home() / "Applications" / "Tauron.app"
                if source.is_dir():
                    shutil.copytree(source, target, dirs_exist_ok=True)
                else:
                    shutil.copy2(source, target)
        print(f"Tauron updated to {latest}.")
        handoff_older_app()
        return True
    except (OSError, ValueError, KeyError, json.JSONDecodeError, zipfile.BadZipFile, urllib.error.URLError):
        # Offline or unavailable update service must never prevent Tauron from starting.
        return False


if __name__ == "__main__":
    # The native app uses this status to restart into the newly installed bundle.
    # The older shell launcher ignores the status and opens the installed app itself.
    sys.exit(10 if main() else 0)
