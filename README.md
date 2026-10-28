# Tauron Terminal

Tauron is a small command language with its own interactive terminal. It is an early starter version written in Python and uses only Python's standard library.

## Start it on macOS

1. Keep `Tauron.command` and `tauron.py` together in the same folder.
2. Open `Tauron.command` from Finder, or start Terminal and run:

   ```sh
   ./Tauron.command
   ```

If macOS reports that the file is not executable, run `chmod +x Tauron.command` once, then open it again. Python 3 must be installed and available as `python3`.

## Commands

`help`, `clear`, `pwd`, `ls`, `cd`, `mkdir`, `touch`, `cat`, `echo`, `cp`, `mv`, `rm`, `head`, `tail`, `wc`, `find`, `date`, `whoami`, `history`, `exit`.

Tauron includes 20 core commands, 100 convenience aliases, and the `mod` and `changelog` commands (for example, `dir` works like `ls`, and `quit` works like `exit`). Type `help` to print the full list and scroll through it in Terminal. Type `help <command>` for usage.

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

For a fresh install, download `tauron-macos.zip` from the [Tauron releases page](https://github.com/krgkonekpro04-cpu/tauron-terminal/releases), extract it, and open `install.command`. It installs Tauron under `~/Library/Application Support/Tauron` and creates the stable launcher `~/bin/tauron`. Launch with `~/bin/tauron`. Tauron checks for a new release each time it launches, installs it automatically when available, then starts. You do not need to visit GitHub or change the launch command to update.

The startup updater checks the public GitHub Releases location configured in `update-config.json`. Each release must include an asset named `tauron-macos.zip` containing the app files and `CHANGELOG.md`. The updater fails quietly when offline or when no newer release exists. Type `changelog` inside Tauron to read the included release notes.
