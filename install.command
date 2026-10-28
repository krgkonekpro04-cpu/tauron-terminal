#!/bin/sh
set -eu

SOURCE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON="$(command -v python3 || true)"
if [ -z "$PYTHON" ]; then
  echo "Tauron needs Python 3. Install Python 3 and run this installer again."
  exit 1
fi
APP="$HOME/Library/Application Support/Tauron"
BIN="$HOME/bin"
APPLICATIONS="$HOME/Applications"
mkdir -p "$APP" "$BIN" "$APPLICATIONS"
ditto "$SOURCE" "$APP"
ditto "$SOURCE/Tauron.app" "$APPLICATIONS/Tauron.app"
cat > "$BIN/tauron" <<'LAUNCHER'
#!/bin/sh
open "$HOME/Applications/Tauron.app" "$@"
LAUNCHER
chmod +x "$BIN/tauron" "$APP/Tauron.command" "$APPLICATIONS/Tauron.app/Contents/MacOS/Tauron"
echo "Tauron Desktop installed at: ~/Applications/Tauron.app"
echo "Launch the independent window with: ~/bin/tauron"
echo "Save personal mods in ~/Documents/Tauron/Mods to keep them separate from app updates."
