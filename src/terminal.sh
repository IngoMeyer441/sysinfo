# shellcheck shell=bash

check_supported_colors () {
    if [[ -z "${COLOR_MODE}" || "${COLOR_MODE}" == "auto" ]]; then
        [[ $COLORTERM =~ ^(truecolor|24bit)$ ]] && { echo "truecolor"; return; }
        command_available tput && { tput colors; return; }
        echo "16"  # Assume a minimum of 16 colors as fallback
    else
        echo "${COLOR_MODE}"
    fi
}

init_terminal_formatting () {
    local escape

    if command_available tput; then
        TERM_RESET="$(tput sgr0)"
        TERM_CURSOR_INVISIBLE="$(tput civis)"
        TERM_CURSOR_VISIBLE="$(tput cnorm)"
        TERM_CURSOR_UP="$(tput cuu1)"
        # TERM_BOLD="$(tput bold)"
        # TERM_FG_BLACK="$(tput setaf 0)"
        # TERM_FG_RED="$(tput setaf 1)"
        # TERM_FG_GREEN="$(tput setaf 2)"
        # TERM_FG_YELLOW="$(tput setaf 3)"
        # TERM_FG_BLUE="$(tput setaf 4)"
        # TERM_FG_MAGENTA="$(tput setaf 5)"
        # TERM_FG_CYAN="$(tput setaf 6)"
        # TERM_FG_WHITE="$(tput setaf 7)"
    else
        >&2 echo "Could not query the terminal database, assume an xterm compatible terminal."
        escape="$(printf "\033")"
        # shellcheck disable=SC2034
        TERM_RESET="${escape}[0m"
        # shellcheck disable=SC2034
        TERM_CURSOR_INVISIBLE="${escape}[?25l"
        # shellcheck disable=SC2034
        TERM_CURSOR_VISIBLE="${escape}[?12l${escape}[?25h"
        # shellcheck disable=SC2034
        TERM_CURSOR_UP="${escape}[A"
        # TERM_BOLD="${escape}[1m"
        # TERM_FG_BLACK="${escape}[30m"
        # TERM_FG_RED="${escape}[31m"
        # TERM_FG_GREEN="${escape}[32m"
        # TERM_FG_YELLOW="${escape}[33m"
        # TERM_FG_BLUE="${escape}[34m"
        # TERM_FG_MAGENTA="${escape}[35m"
        # TERM_FG_CYAN="${escape}[36m"
        # TERM_FG_WHITE="${escape}[37m"
    fi
}

get_cursor_column () {
    local dummy pos row col
    echo -ne "\033[6n" > /dev/tty
    # shellcheck disable=SC2034
    read -rs -d\[ dummy
    read -rs -dR pos
    # shellcheck disable=SC2034
    IFS=";" read -rs row col <<< "${pos}"
    echo "$(( col - 1 ))"
}

get_terminal_width () {
    if command_available tput; then
        tput cols
        return
    fi
    if [[ -n "${COLUMNS}" ]]; then
        echo "${COLUMNS}"
        return
    fi
    init_script_tmp_dir || return
    if [[ ! -f "${SCRIPT_TMP_DIR}/showed_term_width_warning" ]]; then
        >&2 echo "Could not query terminal width, assume 80 columns."
        touch "${SCRIPT_TMP_DIR}/showed_term_width_warning"
    fi
    echo "80"
}
