# shellcheck shell=bash

check_supported_colors () {
    if [[ -z "${COLOR_MODE}" || "${COLOR_MODE}" == "auto" ]]; then
        [[ $COLORTERM =~ ^(truecolor|24bit)$ ]] && { echo "truecolor"; return; }
        command -v tput &>/dev/null && { tput colors; return; }
        echo "16"  # Assume a minimum of 16 colors as fallback
    else
        echo "${COLOR_MODE}"
    fi
}

init_terminal_formatting () {
    command_available tput || return

    # shellcheck disable=SC2034
    TERM_RESET="$(tput sgr0)"
    # shellcheck disable=SC2034
    TERM_BOLD="$(tput bold)"
    # TERM_FG_BLACK="$(tput setaf 0)"
    # TERM_FG_RED="$(tput setaf 1)"
    # TERM_FG_GREEN="$(tput setaf 2)"
    # TERM_FG_YELLOW="$(tput setaf 3)"
    # TERM_FG_BLUE="$(tput setaf 4)"
    # TERM_FG_MAGENTA="$(tput setaf 5)"
    # shellcheck disable=SC2034
    TERM_FG_CYAN="$(tput setaf 6)"
    # TERM_FG_WHITE="$(tput setaf 7)"
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
    command -v tput &>/dev/null || return 1
    tput cols
}
