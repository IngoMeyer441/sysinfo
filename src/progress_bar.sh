# shellcheck shell=bash

# PROGRESS_CHARACTERS=( "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█" )
HORIZONTAL_PROGRESS_CHARACTERS=( "╸" "━" )

VERTICAL_PROGRESS_CHARACTERS=( "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" )


get_color_index_for_progress () {
    local current_value min_value max_value available_color_count invert_color

    current_value="$1"
    min_value="$2"
    max_value="$3"
    available_color_count="$4"
    invert_color="$(parse_bool_value "$5" )"

    awk \
        -v current_value="${current_value}" \
        -v min_value="${min_value}" \
        -v max_value="${max_value}" \
        -v available_color_count="${available_color_count}" \
        -v invert_color="${invert_color}" \
        "BEGIN { \
            if (!invert_color) { \
                color_index = int((current_value - min_value) / (max_value - min_value) * (available_color_count)); \
            } else { \
                color_index = int( \
                    (1 - (current_value - min_value) / (max_value - min_value)) * (available_color_count) \
                ); \
            }
            if (color_index >= available_color_count) {
                color_index = available_color_count - 1
            }
            printf(\"%d\", color_index); \
        }"
}

get_16_color_for_progress () {
    local color_indices current_value min_value max_value invert_color color_index

    color_indices=( 1 3 2 )

    current_value="$1"
    min_value="$2"
    max_value="$3"
    invert_color="$4"

    if (( current_value < 0 )); then
        # A negative value indicates a background progress bar segment
        printf "%d" 0
        return
    fi

    color_index="$( \
        get_color_index_for_progress \
            "${current_value}" \
            "${min_value}" \
            "${max_value}" \
            "${#color_indices[@]}" \
            "${invert_color}" \
    )"

    echo "${color_indices[${color_index}]}"
}

get_256_color_for_progress () {
    local color_indices current_value min_value max_value invert_color color_index

    color_indices=( 196 202 208 214 220 226 190 154 118 82 46 )

    current_value="$1"
    min_value="$2"
    max_value="$3"
    invert_color="$4"

    if (( current_value < 0 )); then
        # A negative value indicates a background progress bar segment
        printf "%d" 236
        return
    fi

    color_index="$( \
        get_color_index_for_progress \
            "${current_value}" \
            "${min_value}" \
            "${max_value}" \
            "${#color_indices[@]}" \
            "${invert_color}" \
    )"

    echo "${color_indices[${color_index}]}"
}

get_rgb_color_for_progress () {
    local current_value min_value max_value invert_color

    current_value="$1"
    min_value="$2"
    max_value="$3"
    invert_color="$(parse_bool_value "$4" )"

    if (( current_value < 0 )); then
        # A negative value indicates a background progress bar segment
        printf "%d;%d;%d" 51 51 51
        return
    fi

    awk \
        -v current_value="${current_value}" \
        -v min_value="${min_value}" \
        -v max_value="${max_value}" \
        -v invert_color="${invert_color}" \
        "BEGIN { \
            available_color_count = 2 * 256 - 1
            if (!invert_color) { \
                color_index = int( \
                    (current_value - min_value) / (max_value - min_value) * (available_color_count - 1) \
                ); \
            } else { \
                color_index = int( \
                    (1 - (current_value - min_value) / (max_value - min_value)) * (available_color_count - 1) \
                ); \
            }
            if (color_index < 256) {
                r = 255
                g = color_index
            } else {
                r = available_color_count - color_index - 1
                g = 255
            }
            b = 0
            printf(\"%d;%d;%d\", r, g, b); \
        }"
}

set_progress_bar_color () {
    local current_value min_value max_value invert_color

    current_value="$1"
    min_value="$2"
    max_value="$3"
    invert_color="$4"

    case "$(check_supported_colors)" in
        truecolor)
            printf "\x1b[38;2;%sm" "$( \
                get_rgb_color_for_progress "${current_value}" "${min_value}" "${max_value}" "${invert_color}" \
            )"
            ;;
        256)
            printf "\x1b[38;5;%dm" "$( \
                get_256_color_for_progress "${current_value}" "${min_value}" "${max_value}" "${invert_color}" \
            )"
            ;;
        *)
            printf "\x1b[%dm" "$(( \
                $(get_16_color_for_progress "${current_value}" "${min_value}" "${max_value}" "${invert_color}") + 30 \
            ))"
            ;;
    esac
}

set_progress_bar_backgrond_color () {
    case "$(check_supported_colors)" in
        truecolor)
            printf "\x1b[48;2;%sm" "51;51;51"
            ;;
        256)
            printf "\x1b[48;5;%dm" "236"
            ;;
        *)
            printf "\x1b[%dm" "40"
            ;;
    esac
}

draw_horizontal_progress_bar () {
    local current_value min_value max_value invert_color columns full_segments partial_segment_index

    current_value="$1"
    min_value="$2"
    max_value="$3"
    invert_color="$4"
    columns="$5"

    IFS=";" read -rs full_segments partial_segment_index < <( \
        awk \
            -v current_value="${current_value}" \
            -v min_value="${min_value}" \
            -v max_value="${max_value}" \
            -v columns="${columns}" \
            -v partial_step_count="${#HORIZONTAL_PROGRESS_CHARACTERS[@]}" \
            "BEGIN { \
                segments = (current_value - min_value) / (max_value - min_value) * columns; \
                full_segments = int(segments); \
                printf(\"%d;%d\", full_segments, int((segments - full_segments) * partial_step_count) - 1); \
            }" \
    )

    set_progress_bar_color "${current_value}" "${min_value}" "${max_value}" "${invert_color}"
    repeat_char "${HORIZONTAL_PROGRESS_CHARACTERS[$(( ${#HORIZONTAL_PROGRESS_CHARACTERS[@]} - 1 ))]}" "${full_segments}"
    if (( partial_segment_index >= 0 )); then
        printf "%s" "${HORIZONTAL_PROGRESS_CHARACTERS[${partial_segment_index}]}"
    fi
    set_progress_bar_color "-1" "${min_value}" "${max_value}"
    repeat_char \
        "${HORIZONTAL_PROGRESS_CHARACTERS[$(( ${#HORIZONTAL_PROGRESS_CHARACTERS[@]} - 1 ))]}" \
        "$(( columns - full_segments - (partial_segment_index >= 0 ? 1 : 0 ) ))"

    printf "%s" "${TERM_RESET}"
}

draw_vertical_progress_bar () {
    local current_value min_value max_value invert_color segment_index

    current_value="$1"
    min_value="$2"
    max_value="$3"
    invert_color="$4"

    segment_index="$( \
        awk \
            -v current_value="${current_value}" \
            -v min_value="${min_value}" \
            -v max_value="${max_value}" \
            -v segment_count="${#VERTICAL_PROGRESS_CHARACTERS[@]}" \
            "BEGIN { \
                segment_index = int((current_value - min_value) / (max_value - min_value) * segment_count) - 1; \
                printf(\"%d\", segment_index); \
            }" \
    )"

    set_progress_bar_backgrond_color
    set_progress_bar_color "${current_value}" "${min_value}" "${max_value}" "${invert_color}"

    if (( segment_index >= 0 )); then
        printf "%s" "${VERTICAL_PROGRESS_CHARACTERS[${segment_index}]}"
    else
        printf " "
    fi

    printf "%s" "${TERM_RESET}"
}
