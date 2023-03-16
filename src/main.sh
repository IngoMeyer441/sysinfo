# shellcheck shell=bash

main () {
    # TODO: Remove this check when other operating systems are supported
    if [[ "$(uname -s)" != "Linux" ]]; then
        >&2 echo "Your OS \"$(uname -s)\" is not supported yet."
        return 1
    fi
    init_terminal_formatting && \
    process_command_line_arguments "$@" && \
    display_infos
}

main "$@"

exit
