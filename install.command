#!/bin/sh
set -eu

SOURCE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP="$HOME/Library/Application Support/Tauron"
BIN="$HOME/bin"
mkdir -p "$APP" "$BIN"
ditto "$SOURCE" "$APP"
cat > "$BIN/tauron" <<'LAUNCHER'
#!/bin/sh
exec "$HOME/Library/Application Support/Tauron/Tauron.command" "$@"
LAUNCHER
chmod +x "$BIN/tauron" "$APP/Tauron.command"
echo "Tauron installed. Launch it with: ~/bin/tauron"
echo "Save personal mods in ~/Documents/Tauron/Mods to keep them separate from app updates."
