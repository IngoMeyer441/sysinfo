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

## Integration with sshrc

Since sysinfo is a quite small shell script, it can be combined with [sshrc](https://github.com/IngoMeyer441/sshrc) to
display system information on every login to your servers. The following snippet can be appended to your `~/.sshrc` to
start [tmux](https://github.com/tmux/tmux) on login, open a new split pane at the bottom and run `sysinfo` in it. This
has the advantage that you don't need to wait for `sysinfo` to finish and can start typing in the other split pane at
the top immediately. In addition, the system usage fields are updated continuously.

```bash
# Do not execute `tmux` if run before (no nesting)
if [[ -z "${TMUX}" ]]; then
    if command -v tmux >/dev/null 2>&1; then
        tmuxrc && exit
    else
        >&2 echo "tmux cannot be started because it is not installed."
    fi
# Print system information on login
elif [[ -x "${SSHHOME}/.sshrc.d/bin/sysinfo" ]] && [[ ! -e "${SSHHOME}/.sysinfo_was_run" ]]; then
    sysinfo_options="--continuous=20"
    # if tmux version >= 2.2
    if [[ \
        "$(echo "$(tmux -V | cut -d" " -f2);2.2" | tr ";" "\n" | sort -g -t "." -k 1,1 -k 2,2 | head -1)" == "2.2" \
       ]]; then
        sysinfo_options="${sysinfo_options} --color=truecolor"
    fi
    tmux split-window \
        -d \
        -l "$( \
            awk \
                -v pane_height="$(tmux display -p '#{pane_height}')" \
                -v desired_height="12" \
                'BEGIN { printf("%d", pane_height / 2 < desired_height ? pane_height / 2 : desired_height) }' \
        )" \
        "if ! \"${SSHHOME}/.sshrc.d/bin/sysinfo\" ${sysinfo_options}; then sleep 5; fi"
    touch "${SSHHOME}/.sysinfo_was_run"
fi
```

Please note for this snippet to work:

- You need the [`tmuxrc`](https://github.com/IngoMeyer441/sshrc#tmux) example function in your `~/.sshrc`.
- `sysinfo` must be installed to `~/.sshrc.d//bin/sysinfo`.
