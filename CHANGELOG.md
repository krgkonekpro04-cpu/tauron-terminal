# Tauron Changelog

## 1.0.2 — Live changelog

- Make `changelog` fetch the current notes from the Tauron GitHub repository whenever it runs.
- Fall back to the bundled changelog when the network is unavailable.

## 1.0.1 — Assistant layout fixes

- Keep the Code/Study and provider dropdown menus above the chat pane so their options are not clipped.
- Hide the prompt placeholder while the editor is focused to keep it clear of the insertion cursor.

## 1.0.0 — Tauron Super Update

- Add Tauron-styled image, audio, and video previews in the Mac folder browser and AI attachment composer, including MP3 and MP4 playback.
- Add 1,014 named unit-conversion shortcuts across length, mass, volume, time, data, speed, area, and temperature, plus math, text, system, and study commands.
- Add command categories to `help` and a build-generated command catalog that grounds Tauron AI's command advice in the actual runtime.
- Add safe arithmetic, numeric utilities, text transforms, JSON/Base64/URL tools, system information, DNS lookup, calendar, and timer commands.

## 0.8.0 — Glass desktop refresh

- Add translucent material panels, softer gradients, and rounded terminal, file, and chat surfaces.
- Animate switches between Terminal and Tauron AI, new messages, file list updates, and attachment changes.

## 0.7.0 — Study Mode and image attachments

- Add Study mode for step-by-step school tutoring, practice questions, quizzes, and study help from images.
- Add image attachments for Gemini and local Ollama models that support vision.
- Keep Coding mode and its project-context behavior available.

## 0.6.2 — Faster AI replies and thinking dots

- Speed up the Tauron AI typewriter animation to 3 ms per character.
- Show animated one, two, and three-dot thinking status while the model responds.
- Clarify that Ollama runs a downloaded model; it does not create or train Tauron's own model.

## 0.6.1 — In-app Terms of Service

- Show Tauron's Terms of Service on first launch with Learn More, Accept, and Reject actions.
- Require acceptance before the terminal and updater start; choosing Reject closes the app.
- Include the complete terms in the app bundle and repository.

## 0.6.0 — Local-first Tauron AI and Tauron file icons

- Make Ollama the default AI provider so Tauron AI works without a Gemini account or API key.
- Give the on-device model bounded, read-only context from source and Tauron files in the selected folder; replies are branded Tauron AI for either provider.
- Register `.tauron` and `.tau` as Tauron source files and show the Tauron icon in Finder.

## 0.5.2 — Tauron AI typing animation

- Animate AI replies character by character and keep the latest text in view while it types.

## 0.5.1 — Multiline Tauron AI input

- Press Return to send an AI prompt; press Shift+Return to add a line.

## 0.5.0 — Tauron AI with local models and memory

- Renamed Gemini Assistant to Tauron AI.
- Added an Ollama local-model provider alongside Gemini.
- Added editable local memory notes that personalize replies across sessions.

## 0.4.3 — Update handoff for older apps

- Added a compatibility handoff so older desktop builds open the newly updated app on their first update launch.

## 0.4.2 — Legacy updater handoff

- Relaunch the app after updating older native Tauron versions that cannot restart themselves.
- Keep current Tauron releases in control of their own update restart.

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
