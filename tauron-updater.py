#!/usr/bin/env python3
"""Optional GitHub Releases updater for installed Tauron copies."""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def version_key(value: str) -> tuple[int, ...]:
    try:
        return tuple(int(piece) for piece in value.lstrip("v").split(".") if piece.isdigit())
    except ValueError:
        return ()


def main() -> None:
    try:
        config = json.loads((ROOT / "update-config.json").read_text(encoding="utf-8"))
        repo = config.get("github_repository", "").strip()
        if not repo or "/" not in repo:
            return
        request = urllib.request.Request(
            f"https://api.github.com/repos/{repo}/releases/latest",
            headers={"Accept": "application/vnd.github+json", "User-Agent": "Tauron-Updater"},
        )
        with urllib.request.urlopen(request, timeout=2.5) as response:
            release = json.load(response)
        latest = release.get("tag_name", "").lstrip("v")
        current = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        if not latest or version_key(latest) <= version_key(current):
            return
        asset = next((item for item in release.get("assets", []) if item.get("name") == "tauron-macos.zip"), None)
        if not asset:
            return
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
            for name in ("tauron.py", "Tauron.command", "tauron-updater.py", "VERSION", "CHANGELOG.md", "examples"):
                source = stage / name
                if not source.exists():
                    continue
                target = ROOT / name
                if source.is_dir():
                    shutil.copytree(source, target, dirs_exist_ok=True)
                else:
                    shutil.copy2(source, target)
        print(f"Tauron updated to {latest}.")
    except (OSError, ValueError, KeyError, json.JSONDecodeError, zipfile.BadZipFile, urllib.error.URLError):
        # Offline or unavailable update service must never prevent Tauron from starting.
        return


if __name__ == "__main__":
    main()
