# Tauron Terminal

Tauron is a small command language with its own interactive terminal. It is an early starter version written in Python and uses only Python's standard library.

## Start it on macOS

Install the downloaded release with `install.command` once. Then open **Tauron.app** from `~/Applications`, or run `~/bin/tauron`. Tauron opens in its own window and does not use the macOS Terminal app.

Tauron Desktop requires Python 3 with Tkinter available. The app uses Python to run Tauron's command engine.

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

On launch, Tauron shows an ASCII title screen and a short status sequence before the prompt.

## Tauron Mod Language

Mods use `.tau` text files and are interpreted by Tauron; they cannot run arbitrary Python or shell code. Start with `examples/hello.tau`, then load it in Tauron with `mod load examples/hello.tau`. Use `mod list` to see loaded mods and `mod unload hello` to remove one until Tauron exits.

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

The left pane browses your Mac folders. Choose a folder or double-click one in the list; Tauron's `ls`, `cat`, `touch`, `cp`, `mv`, and other file commands operate directly on files in that folder. There is no separate copy or cloud sync: changes are made to the selected Mac files immediately.

The startup updater checks the public GitHub Releases location configured in `update-config.json`. Each release must include an asset named `tauron-macos.zip` containing the app files and `CHANGELOG.md`. The updater fails quietly when offline or when no newer release exists. Type `changelog` inside Tauron to read the included release notes.
