# Tauron Changelog

## 0.4.1 — Automatic update startup

- Restart Tauron automatically into an update after the app bundle is replaced.
- Find Python 3 in common macOS install locations when Tauron is opened from Finder.

## 0.4.0 — Gemini assistant

- Added an optional Gemini coding and Tauron command assistant to Tauron Desktop.
- Added secure API key storage in macOS Keychain and text/code file attachments for review.
- Assistant responses are suggestions; Tauron does not execute AI-generated commands or apply AI edits.

## 0.3.0 — Native macOS interface

- Replaced the blank desktop window with a native SwiftUI macOS app.
- Kept Tauron's command engine and direct Mac folder access in the app.
- Removed the Tkinter requirement.

## 0.2.2 — Mac window display

- Switched to native Mac controls so the desktop interface and command output display reliably.
- Added scrollbars to the file browser and command output.

## 0.2.1 — Desktop app launch

- Fixed the standalone app executable permission in the downloadable release.

## 0.2.0 — Tauron Desktop

- Added a separate macOS desktop window with a scrollable command area.
- Added a Mac folder browser and folder chooser; file commands work directly on the selected folder.
- Updated the stable `~/bin/tauron` launcher to open Tauron Desktop.

## 0.1.2 — Launcher permissions

- Fixed executable permissions for the macOS installer and terminal launcher in the release download.

## 0.1.1 — Installer and command notes

- Added the `changelog` command.
- Included the one-time macOS installer in the release download.
- Configured automatic update checks at launch and stable `~/bin/tauron` launch path.

## 0.1.0 — First public release

- Added the Tauron interactive terminal with 20 core commands and command aliases.
- Added the cyber-console startup screen.
- Added `.tau` mods with custom commands, variables, conditionals, and repeats.
- Added the macOS installer and automatic release updater.
- Added the `changelog` command.
