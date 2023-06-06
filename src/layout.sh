# shellcheck shell=bash

HORIZONTAL_PROGRESS_BAR_MIN_WIDTH=10

get_info_field_length () {
    local info_field transformed_info_field

    info_field="$1"
    transformed_info_field="$( \
        sed \
            -e "s/{{\s*horizontal_progress_bar[^}]*}}/$(repeat_char "*" "${HORIZONTAL_PROGRESS_BAR_MIN_WIDTH}")/g" \
            -e 's/{{[^}]*}}/*/g' \
        <<< "${info_field}" \
    )"

    echo "${#transformed_info_field}"
}

render_and_print_info_line () {
    local print_line current_line_length available_text_width expanding_elements_count additional_columns_per_element
    local additional_columns_remainder fill_chars_count text_until_next_function function_call function_name
    local function_args progress_bar_width

    print_line="$1"
    current_line_length="$2"
    available_text_width="$3"

    expanding_elements_count="$(grep -o '{{\s*horizontal_progress_bar[^}]*}}' <<< "${print_line}" | wc -l)"
    if (( expanding_elements_count > 0 )); then
        read -r additional_columns_per_element additional_columns_remainder < <( \
            awk \
                -v current_line_length="${current_line_length}" \
                -v available_text_width="${available_text_width}" \
                -v expanding_elements_count="${expanding_elements_count}" \
                'BEGIN { \
                    remaining_columns = available_text_width - current_line_length; \
                    printf( \
                        "%d %d", \
                        int(remaining_columns / expanding_elements_count), \
                        remaining_columns % expanding_elements_count \
                    ); \
                }'
        )
        fill_chars_count=0
    else
        additional_columns_per_element=0
        additional_columns_remainder=0
        fill_chars_count="$(awk \
            -v current_line_length="${current_line_length}" \
            -v available_text_width="${available_text_width}" \
            'BEGIN { \
                remaining_columns = available_text_width - current_line_length; \
                printf("%d", remaining_columns); \
            }' \
        )"
    fi

    while grep -q '{{' <<< "${print_line}"; do
        text_until_next_function="$(grep -Po '^[^{]*(?={{)' <<< "${print_line}")"
        printf "%s" "${text_until_next_function}"
        print_line="${print_line:${#text_until_next_function}}"
        function_call="$(grep -Po '^{{\s*\K[^}]*(?=\s*}})' <<< "${print_line}")"
        function_name="$(grep -o '^[^(]*' <<< "${function_call}")"
        mapfile -t function_args < <( \
            grep -Po '(?<=\()[^)]*(?=\))' <<< "${function_call}" | \
            awk -F'[, ]*' '{ for (i = 1; i <= NF; ++i) print $i }' \
        )
        case "${function_name}" in
            horizontal_progress_bar)
                progress_bar_width="$(( \
                    HORIZONTAL_PROGRESS_BAR_MIN_WIDTH + \
                    additional_columns_per_element + \
                    (additional_columns_remainder > 0 ? 1 : 0)
                ))"
                if (( ${#function_args[@]} < 4 )); then
                    # `invert_color` is an optional argument which defaults to `false`
                    function_args+=( "false" )
                fi
                draw_horizontal_progress_bar "${function_args[@]}" "${progress_bar_width}"
                (( --additional_columns_remainder ))
                ;;
            vertical_progress_bar)
                draw_vertical_progress_bar "${function_args[@]}"
                ;;
            *)
                >&2 echo "The text function \"${function_name}\" is not supported."
                ;;
        esac
        print_line="$(grep -Po '^{{[^}]*}}\K.*' <<< "${print_line}")"
    done
    printf "%s" "${print_line}"
    repeat_char " " "${fill_chars_count}"
}

print_info_text () {
    local left_padding available_text_width info_lines is_first_line i current_line_length info_line info_field
    local info_field_length print_line prepand_space

    left_padding="$1"
    available_text_width="$2"
    mapfile -t info_lines <<< "$3"

    is_first_line=1
    i=0
    for info_line in "${info_lines[@]}"; do
        if ! (( is_first_line )); then
            repeat_char " " "${left_padding}"
        fi
        current_line_length="${left_padding}"
        print_line=""
        while IFS= read -r info_field; do
            if [[ "${info_field:0:1}" == ";" ]]; then
                prepand_space=0
                info_field="${info_field:1}"
            else
                prepand_space=1
            fi
            info_field_length=$(get_info_field_length "${info_field}")
            (( info_field_length > 0 )) || continue
            if (( current_line_length > left_padding )) && \
                (( current_line_length + info_field_length > available_text_width )); then
                render_and_print_info_line "${print_line}" "${current_line_length}" "${available_text_width}"
                printf "\n"
                repeat_char " " "${left_padding}"
                current_line_length="${left_padding}"
                print_line=""
            fi
            if (( prepand_space )); then
                print_line="${print_line} ${info_field}"
                (( current_line_length += info_field_length + 1 ))
            else
                print_line="${print_line}${info_field}"
                (( current_line_length += info_field_length ))
            fi
        done < <(awk -v RS=';;' '{ print }' <<< "${info_line}")
        render_and_print_info_line "${print_line}" "${current_line_length}" "${available_text_width}"
        if (( i < ${#info_lines[@]}-1 )); then
            printf "\n"
        fi
        is_first_line=0
        (( ++i ))
    done
}
