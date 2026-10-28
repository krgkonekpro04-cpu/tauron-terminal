# Tauron Terminal

Tauron is a small command language with its own interactive terminal. It is an early starter version written in Python and uses only Python's standard library.

## Start it on macOS

Install the downloaded release with `install.command` once. Then open **Tauron.app** from `~/Applications`, or run `~/bin/tauron`. Tauron opens in its own window and does not use the macOS Terminal app.

Tauron Desktop uses a native macOS interface and Python 3 to run Tauron's command engine. Tkinter is not required.

On first launch, Tauron displays its Terms of Service inside the app. Read them there, use **Learn More** for a plain-language summary, then choose **Accept** to continue or **Reject** to close Tauron. Tauron remembers acceptance for that terms version.

## Tauron AI

Select **Tauron AI** in Tauron Desktop and choose **Code** or **Study** mode. Study mode tutors school subjects with step-by-step explanations, practice questions, quizzes, and image help. Coding mode helps with Tauron commands, `.tau`/`.tauron` source files, and programming. Attach a PNG, JPEG, GIF, or WebP image (up to 10 MB) to ask about a diagram, worksheet, or other visual. An Ollama model must support vision to understand images.

**Ollama (on this Mac)** is the default: Ollama runs an open model that you download once, then Tauron can use it locally, including offline. Ollama is a model runner, not the model itself. This makes Tauron independent from Gemini, but it does not mean Tauron has its own trained model. Tauron supplies the local model with up to eight readable source files from the selected folder in Coding mode, plus any file or image you attach and the notes you saved. This context stays on the Mac with Ollama. **Gemini (optional cloud)** remains available if you choose it and connect your own Google AI Studio API key; prompts, images, text attachments, and saved notes then go to Google's API. Tauron stores that key in macOS Keychain. The assistant suggests commands and edits but does not execute commands or change files.

In the Tauron AI prompt, press Return to send and Shift+Return to insert a new line.

Tauron AI can remember preferences and project notes you add under **Memory**. Those notes are kept in `~/Library/Application Support/Tauron/ai-memory.json` and can be deleted in the app. This is local memory used as context; it does not change or train model weights. Gemini's current API does not support model fine-tuning. Ollama lets Tauron use a separate local model, and open-weight models can be fine-tuned outside Tauron if you later want to build a genuinely Tauron-trained model.

## Commands

`help`, `clear`, `pwd`, `ls`, `cd`, `mkdir`, `touch`, `cat`, `echo`, `cp`, `mv`, `rm`, `head`, `tail`, `wc`, `find`, `date`, `whoami`, `history`, `exit`.

Tauron includes 20 core commands, 100 convenience aliases, and the `mod` and `changelog` commands (for example, `dir` works like `ls`, and `quit` works like `exit`). Type `help` to print the full list and scroll through it in Tauron. Type `help <command>` for usage.

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

The left pane browses your Mac folders. Choose a folder or double-click one in the list; Tauron's `ls`, `cat`, `touch`, `cp`, `mv`, and other file commands operate directly on files in that folder. There is no separate copy or cloud sync: changes are made to the selected Mac files immediately.

The startup updater checks the public GitHub Releases location configured in `update-config.json`. Each release must include an asset named `tauron-macos.zip` containing the app files and `CHANGELOG.md`. The updater fails quietly when offline or when no newer release exists. Type `changelog` inside Tauron to read the included release notes.
