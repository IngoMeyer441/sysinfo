# sysinfo

## Overview

sysinfo shows system information like the hardware configuration and resource usage in a compact, clearly arranged and
visually pleasing style. It only depends on Bash >= 3 and standard Unix tools like awk.

![screenshot](https://raw.githubusercontent.com/IngoMeyer441/sysinfo/master/screenshot.png)

Currently, only Linux is supported, but macOS support is planned for the future.

## Installation

You can either download the latest release from the [releases
page](https://github.com/IngoMeyer441/sysinfo/releases/latest) or build it from source with

```bash
make build
```

You will find the `sysinfo` executable (which is in fact only a Bash script) in `src/sysinfo`.

On Arch and its derivatives you can install `sysinfo` from the [AUR](https://aur.archlinux.org/packages/sysinfo/):

```bash
yay -S sysinfo
```

## Usage

Run `sysinfo` without any arguments to list current system information and exit. The script will detect automatically
which colors are supported by your terminal emulator and will select either the 16 or 256 color palette or true color.
If the auto-detection should fail, you can select the correct color mode with the `--color` switch (`16`, `256` or
`truecolor`). Add the `-o` / `--continuous` option to update the resource usage display continuously. This will run
until interrupted with `<Ctrl-C>`. Alternatively, you can pass an amount of seconds after `-o` / `--continuous` to exit
the program automatically.
