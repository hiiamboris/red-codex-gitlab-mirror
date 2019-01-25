### RedCodeX

![](https://i.gyazo.com/9db30cad1e6ceb7b3248b5df6be59881.gif)

**Purpose**: help study [Red](https://www.red-lang.org) source code.

It works by indexing all source files' words and set-words and allows you in 1 click to **find** where a particular thing was **defined** or **used**.
As many files can be kept open as required.

### Get started:
#### 1. Clone the [Red repo](https://github.com/red/red/) somewhere
#### 2. Put the [compiled exe](https://gitlab.com/hiiamboris/red-codex/raw/master/redcodex.exe) there and start it
- *Please run the exe from `cmd` shell, so if it **crashes** you'll know the reason!* All crashes should be **reported** to me on [Gitter](https://gitter.im/red/bugs) - in doing so you can make Red better!
- There's also an [exe version without GC](https://gitlab.com/hiiamboris/red-codex/raw/master/redcodex-nogc.exe) for those who get frequent crashes in `red/collector/` context.
- Alternatively, you can run [the script](https://gitlab.com/hiiamboris/red-codex/raw/master/redcodex.red) in [Red interpreter](https://w.red-lang.org/download/) or compile it with `red -r -e -d redcodex.red` command yourself. In this case [glob dependency](https://gitlab.com/hiiamboris/red-junk/raw/master/glob/glob.red) is required but will be fetched from online sources if you haven't downloaded it.

### Tips:
- Controls are hard-coded for now: press **F1** and study what's available. Fully tablet-friendly now!
- Editor is invoked with `edit` command, that should be defined in your PATH variable. If that option doesn't work for you, modify the [`config/run-cmd`](https://gitlab.com/hiiamboris/red-codex/blob/master/redcodex.red#L73) directly.
