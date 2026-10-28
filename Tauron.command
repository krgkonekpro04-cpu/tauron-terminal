#!/bin/sh
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ -f "$HERE/tauron-updater.py" ]; then
  /usr/bin/env python3 "$HERE/tauron-updater.py"
fi
exec /usr/bin/env python3 "$HERE/tauron.py"
