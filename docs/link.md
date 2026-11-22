# Using a system clang

[中文](zh-CN/link.md) | [English](link.md)

`vfox link --detect clang` lets the plugin look for LLVM installations that are already
on the machine and link them, so vfox uses them as versions without downloading another
copy. It needs vfox 1.1.0 or later.

``` shell
vfox link --detect clang        # lists what it finds and asks before linking
vfox link --detect clang --yes  # links everything it finds
```

Each linked installation appears in `vfox list clang` with its path:

``` text
-> 19.1.7 (linked → /usr/lib/llvm-19)
```

Then use it like any other version:

``` shell
vfox use clang@19.1.7
```

## Where it looks

The plugin looks only at the places below. An installation is a directory that holds
`bin/clang`, or `bin\clang.exe` on Windows, and whose `clang --version` prints
`clang version X.Y.Z`.

| Platform | Place                                                                                   | Note                       |
| :------- | :-------------------------------------------------------------------------------------- | :------------------------- |
| Linux    | `/usr/lib/llvm-<N>`, `/usr/lib64/llvm<N>`                                               | system LLVM               |
| Linux    | `/opt/llvm*`, `/usr/local`                                                              | installed under /opt, /usr/local |
| Linux    | `/home/linuxbrew/.linuxbrew/opt/llvm*`, `~/.linuxbrew/opt/llvm*`                        | installed by Homebrew      |
| macOS    | `/opt/homebrew/opt/llvm*`, `/usr/local/opt/llvm*`                                       | installed by Homebrew      |
| macOS    | `/opt/llvm*`, `/usr/local`                                                              | installed under /opt, /usr/local |
| Windows  | `%ProgramFiles%\LLVM`, `%ProgramFiles(x86)%\LLVM`                                       | installed by the LLVM installer |
| Windows  | `%ProgramFiles%\Microsoft Visual Studio\<year>\<edition>\VC\Tools\Llvm\{x64,ARM64,}`    | bundled with Visual Studio |
| Windows  | `%USERPROFILE%\scoop\apps\llvm\current`                                                 | installed by Scoop         |
| Windows  | `C:\msys64\clang64`, `C:\msys64\ucrt64`                                                 | installed by MSYS2         |
| All      | `$CONDA_PREFIX`, when set                                                               | pointed to by CONDA_PREFIX |

Folder names are matched as follows. In the system library directories `/usr/lib` and
`/usr/lib64`, only `llvm-<N>` and `llvm<N>` match. In `/opt` and in Homebrew's `opt`
directories, any name that starts with `llvm` matches, so `llvm@18` is found too.

## Rules

- **Apple's clang is never used.** `/usr/bin/clang` from the Command Line Tools is a stub
  that asks to install them, and it is not LLVM. Use Homebrew's `llvm` for LLVM's own clang
  on macOS.
- **Installs under `.vfox` are never reported**, because vfox installed them.
- **One entry per version.** If the same version is found in several places, the plugin
  lists the first place found, in the order of the table above.
- **Versions are named as `vfox search clang` names them**: `19.1.7`, with no suffix for
  the source. A version name can be used once, so a system clang whose version is already
  installed by vfox, or already linked, is skipped, and `vfox link --detect` says so.
- The list is sorted newest first.

## Link an installation by hand

Any directory with `bin/clang` can be linked under a version name with vfox:

``` shell
vfox link clang@18.1.8 /opt/custom-llvm
```

The directory must hold commands in the `bin` directory the plugin puts on `PATH`.
Use `--force` to point an existing link at another directory.

## Remove a link

`vfox uninstall clang@19.1.7` removes the link and leaves the directory alone:

``` text
Unlinked clang@19.1.7 successfully! /usr/lib/llvm-19 was left untouched.
```
