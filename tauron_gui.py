#!/usr/bin/env python3
"""Upgrade bridge: launches the native Tauron.app after older installs update."""
from pathlib import Path
import subprocess

app = Path.home() / "Applications" / "Tauron.app"
subprocess.Popen(["/usr/bin/open", "-n", str(app)])
