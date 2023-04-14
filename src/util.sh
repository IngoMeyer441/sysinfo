# shellcheck shell=bash

cleanup () {
    if [[ -n "${SCRIPT_TMP_DIR}" ]]; then
        rm -rf "${SCRIPT_TMP_DIR}"
    fi
}
trap cleanup EXIT

init_script_tmp_dir () {
    if [[ -z "${SCRIPT_TMP_DIR}" ]]; then
        SCRIPT_TMP_DIR="$(mktemp -d)"
    fi
}

command_available () {
    local command

    command="$1"

    command -v "${command}" &>/dev/null
}

is_in_array () {
    local elem array_elem

    elem="$1"
    shift

    for array_elem in "$@"; do
        [[ "${elem}" == "${array_elem}" ]] && return 0
    done

    return 1
}

max_string_length () {
    local max_len current_string

    max_len=0
    for current_string in "$@"; do
        max_len="$( \
            awk \
                -v current_max_len="${max_len}" \
                '{ printf("%d", length($0) > current_max_len ? length($0) : current_max_len); exit }' \
            <<< "${current_string}" \
        )"
    done
    echo "${max_len}"
}

parse_bool_value () {
    local bool_value

    bool_value="$1"
    case "$(awk '{ print(tolower($0)) }' <<< "${bool_value}")" in
        1|activated|enabled|on|true|yes)
            echo "1"
            ;;
        *)
            echo "0"
            ;;
    esac
}

repeat_char () {
    local char count

    char="$1"
    count="$2"

    while (( count > 0 )); do
        printf "%s" "${char}"
        (( --count ))
    done
}

bytes_to_human_size () {
    local kibibytes units

    kibibytes="$1"
    units=( "KiB" "MiB" "GiB" "TiB" "PiB" )

    scale=1
    for (( i = 0; i < ${#units[@]} - 1; ++i )); do
        if (( scale*1024 >= kibibytes )); then
            break
        fi
        (( scale *= 1024 ))
    done

    awk \
        -v kibibytes="${kibibytes}" \
        -v scale="${scale}" \
        -v unit="${units[$i]}" \
        'BEGIN { printf("%0.2f %s\n", kibibytes/scale, unit) }'
}
