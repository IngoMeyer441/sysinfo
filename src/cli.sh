# shellcheck shell=bash

print_usage () {
    echo "Usage: $0 [-c color_mode] [-h] [-V]"
    [[ "$1" == "short" ]] && return
    echo
    echo "A small utility to display system information."
    echo
    echo "Options:"
    echo "  -c, --color       Force to use the given color mode (16, 256, truecolor, auto)."
    echo "  -h, --help        Print this help message and exit."
    echo "  -V, --version     Show the version number and exit."
}

process_command_line_arguments () {
    COLOR_MODE="auto"

    while getopts ":c:Vh-:" opt; do
        case ${opt} in
            c)
                if [[ "${OPTARG:0:1}" == "-" ]]; then
                    >&2 echo "Option \"-${opt}\" requires an argument."
                    exit 1
                fi
                COLOR_MODE="${OPTARG}"
                ;;
            V)
                print_version
                exit 0
                ;;
            h)
                print_usage
                exit 0
                ;;
            :)
                >&2 echo "Option \"-${OPTARG}\" requires an argument."
                exit 1
                ;;
            -)
                LONG_OPTARG="${OPTARG#*=}"
                opt="${OPTARG%%=*}"
                case $OPTARG in
                    version)
                        print_version
                        exit 0
                        ;;
                    color=*)
                        if [[ -z "${LONG_OPTARG}" ]]; then
                            >&2 echo "Option \"--${opt}\" requires an argument."
                            exit 1
                        fi
                        COLOR_MODE="${LONG_OPTARG}"
                        ;;
                    color)
                        LONG_OPTARG="${!OPTIND}"
                        if [[ -z "${LONG_OPTARG}" || "${LONG_OPTARG:0:1}" == "-" ]]; then
                            >&2 echo "Option \"--${opt}\" requires an argument."
                            exit 1
                        fi
                        COLOR_MODE="${LONG_OPTARG}"
                        (( ++OPTIND ))
                        ;;
                    help)
                        print_usage
                        exit 0
                        ;;
                    version* | help*)
                        >&2 echo "No argument allowed for the option \"--${opt}\""
                        exit 1
                        ;;
                    '')  # "--" terminates argument processing
                        break
                        ;;
                    *)
                        >&2 echo "Invalid option \"--${OPTARG}\""
                        >&2 print_usage "short"
                        exit 1
                        ;;
                esac
                ;;
            \?)
                >&2 echo "Invalid option: \"-${OPTARG}\""
                >&2 print_usage "short"
                exit 1
                ;;
        esac
    done
    shift "$(( OPTIND - 1 ))"

    if ! is_in_array "${COLOR_MODE}" "16" "256" "truecolor" "auto"; then
        >&2 echo "\"${COLOR_MODE}\" is not a valid color mode. Please select one of:"
        >&2 echo "    \"16\", \"256\". \"truecolor\", \"auto\"."
        exit 1
    fi
}
