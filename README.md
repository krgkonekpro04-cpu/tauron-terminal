# Tauron Terminal

Tauron is a small command language with its own interactive terminal. It is an early starter version written in Python and uses only Python's standard library.

## Start it on macOS

Install the downloaded release with `install.command` once. Then open **Tauron.app** from `~/Applications`, or run `~/bin/tauron`. Tauron opens in its own window and does not use the macOS Terminal app.

Tauron Desktop uses a native macOS interface and Python 3 to run Tauron's command engine. Tkinter is not required.

The desktop interface uses translucent glass panels, rounded controls, and animated transitions between the terminal and AI.

On first launch, Tauron displays its Terms of Service inside the app. Read them there, use **Learn More** for a plain-language summary, then choose **Accept** to continue or **Reject** to close Tauron. Tauron remembers acceptance for that terms version.

## Tauron AI

Select **Tauron AI** in Tauron Desktop and choose **Code** or **Study** mode. Study mode tutors school subjects with step-by-step explanations, practice questions, quizzes, and image help. Coding mode helps with Tauron commands, `.tau`/`.tauron` source files, and programming. Attach a PNG, JPEG, GIF, or WebP image (up to 10 MB) to ask about a diagram, worksheet, or other visual. An Ollama model must support vision to understand images. The AI's command suggestions are grounded in the command catalog generated from the running Tauron command engine; it is instructed not to make up Tauron commands.

The paperclip attachment preview supports images and common audio/video files. MP3, M4A, WAV, AIFF, MP4, MOV, and M4V files preview and play locally in Tauron. The current AI providers receive attached images and text, but not audio/video media contents.

**Ollama (on this Mac)** is the default: Ollama runs an open model that you download once, then Tauron can use it locally, including offline. Ollama is a model runner, not the model itself. This makes Tauron independent from Gemini, but it does not mean Tauron has its own trained model. Tauron supplies the local model with up to eight readable source files from the selected folder in Coding mode, plus any text file or image you attach and the notes you saved. This context stays on the Mac with Ollama. **Gemini (optional cloud)** remains available if you choose it and connect your own Google AI Studio API key; prompts, images, text attachments, and saved notes then go to Google's API. Tauron stores that key in macOS Keychain. The assistant suggests commands and edits but does not execute commands or change files.

In the Tauron AI prompt, press Return to send and Shift+Return to insert a new line.

Tauron AI can remember preferences and project notes you add under **Memory**. Those notes are kept in `~/Library/Application Support/Tauron/ai-memory.json` and can be deleted in the app. This is local memory used as context; it does not change or train model weights. Gemini's current API does not support model fine-tuning. Ollama lets Tauron use a separate local model, and open-weight models can be fine-tuned outside Tauron if you later want to build a genuinely Tauron-trained model.

## Commands

Tauron includes the original file and terminal commands plus math, text, system, study, and conversion tools. It registers 1,014 specific unit-conversion shortcuts, such as `km_to_m`, `convert_g_to_lb`, `c_to_f`, and `gb_to_mib`, alongside the general `convert` command.

Type `help` to print the full scrollable command list, or `help math`, `help text`, `help system`, `help study`, `help files`, `help terminal`, or `help conversions` to filter it. Type `help <command>` for usage. Tauron includes over 1,000 generated conversion shortcuts and 100 convenience aliases (for example, `dir` works like `ls`, and `quit` works like `exit`).

Examples:

```text
help
mkdir notes
cd notes
echo "My first Tauron file"
touch first.txt
```

Tauron currently handles one command per line. Use quotes around arguments that contain spaces. `rm` removes files; it refuses to remove directories. This starter intentionally runs Tauron built-ins only: it does not execute arbitrary shell commands or support pipes and redirection yet.

Tauron Desktop opens as a separate window with a scrollable command area and a live Mac folder browser.

## Tauron Mod Language

Mods use `.tau` text files and are interpreted by Tauron; they cannot run arbitrary Python or shell code. `.tauron` and `.tau` files display the Tauron icon in Finder. Start with `examples/hello.tau`, then load it in Tauron with `mod load examples/hello.tau`. Use `mod list` to see loaded mods and `mod unload hello` to remove one until Tauron exits.

A mod starts with `mod NAME`. Each custom command has `command NAME "description"` and ends with `end`. Instructions are indented for readability. Available instructions are:

```text
say "text {1}"       print text; {1}, {2}, etc. insert command arguments
print "text"         same as say
help "text"          print a help line
set key "value"      save a mod variable
show key             display a variable
if key "value"       run following lines when the value matches
else                  alternate branch for if
done                  end an if/repeat block
repeat 3              repeat the following block (maximum 100 times)
```

Within a command, `{args}` expands to all arguments, `{mod}` to the mod name, `{command}` to the command name, and `{1}`, `{2}`, etc. to individual arguments. Quote text that contains spaces. Type `mod help` for the in-terminal summary.

## Install and updates on macOS

For a fresh install, download `tauron-macos.zip` from the [Tauron releases page](https://github.com/krgkonekpro04-cpu/tauron-terminal/releases), extract it, and open `install.command`. It installs Tauron under `~/Library/Application Support/Tauron`, adds **Tauron.app** to `~/Applications`, and creates the stable launcher `~/bin/tauron`. Launch with `~/bin/tauron`. Tauron checks for a new release each time it launches, installs it automatically when available, then starts. You do not need to visit GitHub or change the launch command to update.

If you already installed the earlier command-line-only Tauron, run the new `install.command` once to switch the same `~/bin/tauron` launcher over to Tauron Desktop. Later updates are automatic.

The left pane browses your Mac folders. Choose a folder or double-click one in the list; Tauron's `ls`, `cat`, `touch`, `cp`, `mv`, and other file commands operate directly on files in that folder. Double-click images, MP3, MP4, M4A, WAV, AIFF, MOV, and M4V files to open Tauron's in-app preview and player. There is no separate copy or cloud sync: changes are made to the selected Mac files immediately.

The startup updater checks the public GitHub Releases location configured in `update-config.json`. Each release must include an asset named `tauron-macos.zip` containing the app files and `CHANGELOG.md`. The updater fails quietly when offline or when no newer release exists. Type `changelog` inside Tauron to read the included release notes.
