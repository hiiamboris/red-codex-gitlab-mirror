#### RedCodeX

![](https://i.gyazo.com/9db30cad1e6ceb7b3248b5df6be59881.gif)

**Purpose**: help study [Red](https://www.red-lang.org) source code.

It works by indexing all source files' words and set-words and allows you in 1 click to **find** where a particular thing was **defined** or **used**.
As many files can be kept open as required.

Controls are hard-coded for now:
- LMB = pan
- LMB double-click = open the file in question (with `edit` command - either define in it in your PATH, or modify [`config/run-cmd`](https://gitlab.com/hiiamboris/red-codex/blob/master/redcodex.red#L68))
- RMB = lookup word in the index / in the source file
- +/- = highlight next/previous word in question
- Arrow keys, tab, wheel navigation as usual

Get started:
- clone the [Red repo](https://github.com/red/red/) somewhere
- put the [compiled exe](https://gitlab.com/hiiamboris/red-codex/raw/master/redcodex.exe) there and start it
- alternatively: run [the script](https://gitlab.com/hiiamboris/red-codex/raw/master/redcodex.red) after you've also downloaded the [glob dependency](https://gitlab.com/hiiamboris/red-junk/raw/master/glob/glob.red)
