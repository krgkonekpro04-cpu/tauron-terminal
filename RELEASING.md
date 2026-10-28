# Tauron release checklist

1. Increase the version in `VERSION` and add release notes to `CHANGELOG.md`.
2. Push the update to the `main` branch.
3. GitHub Actions packages `tauron-macos.zip` with the installer, desktop app bundle, and app files, then publishes a GitHub Release named `vVERSION` (for example, `v0.3.0`).

Installed Tauron checks `krgkonekpro04-cpu/tauron-terminal` for the latest release at launch, downloads a newer ZIP when available, updates the packaged app files, and then starts. It keeps `update-config.json` and user mods outside the updater's replacement list. Network failures do not block launch.
