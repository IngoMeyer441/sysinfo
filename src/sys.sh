# shellcheck shell=bash

INFOS=( \
    "print_cpu_info_linux" \
    "print_gpu_info_linux" \
    "print_ram_and_swap_usage_linux" \
    "print_filesystem_usage_linux" \
)

TWO_PASS_INFOS=( \
    "print_cpu_usage_linux" \
)

print_cpu_info_linux () {
    local cpu_model core_count thread_count socket_count

    cpu_model="$(awk -F'\\s+:\\s+' '$1 == "model name" { print $2; exit }' /proc/cpuinfo)"
    socket_count="$( \
        awk -F'\\s+:\\s+' '$1 == "physical id" && !a[$2]++ { ++sockets } END { print sockets }' /proc/cpuinfo \
    )"
    core_count="$(awk -F'\\s+:\\s+' '$1 == "core id" && !a[$2]++ { ++cores } END { print cores }' /proc/cpuinfo)"
    thread_count="$(awk -F'\\s+:\\s+' '$1 == "core id" { ++threads } END { print threads }' /proc/cpuinfo)"

    echo "CPU"
    echo "${cpu_model}, ${socket_count} sockets, ${core_count} cores, ${thread_count} threads"
}

print_gpu_info_linux () {
    local nvidia_card_pci_addresses pci_address gpu_models gpu_model

    nvidia_card_pci_addresses=()
    if [[ -d "/proc/driver/nvidia/gpus" ]]; then
        mapfile -t nvidia_card_pci_addresses < <(ls /proc/driver/nvidia/gpus)
    fi

    if (( "${#nvidia_card_pci_addresses[@]}" <= 1 )); then
        echo "Dedicated GPU"
    else
        echo "Dedicated GPUs"
    fi

    gpu_models=()
    for pci_address in "${nvidia_card_pci_addresses[@]}"; do
        gpu_model="$(awk \
            -F':\\s+' \
            '$1 == "Model" { print $2; exit }' \
            "/proc/driver/nvidia/gpus/${pci_address}/information" \
        )"
        if [[ -n "${gpu_model}" ]]; then
            gpu_models+=("${gpu_model}")
        fi
    done
    if (( "${#gpu_models[@]}" > 0 )); then
        for gpu_model in "${gpu_models[@]}"; do
            echo "${gpu_model}"
        done
    else
        # TODO: Detect more dedicated GPU chips
        echo "(no NVIDIA card detected)"
    fi
}

print_cpu_usage_linux () {
    local print_values used_cpu total_cpu i cpu_cores
    declare -ga used_cpu_diffs total_cpu_diffs

    print_values="$(( ${#used_cpu_diffs[@]} ))"

    i=0
    while read -r used_cpu total_cpu; do
        (( used_cpu_diffs[i] = used_cpu - ${used_cpu_diffs[$i]:-0} ))
        (( total_cpu_diffs[i] = total_cpu - ${total_cpu_diffs[$i]:-0} ))
        (( ++i ))
    done < <(awk \
        '$1 ~ "^cpu" { \
            total = 0; \
            for (i = 2; i <= NF; ++i) total += $i; \
            idle = $5; \
            used = total - idle; \
            printf("%d %d\n", used, total) \
        }' < /proc/stat)
    cpu_cores="$(( i - 1 ))"

    (( print_values )) || return 0

    echo "CPU usage"
    printf "Overall: %d %% / %d %% %s;;Cores:;;" \
        "$(awk \
            -v used_cpu_diff="${used_cpu_diffs[0]}" \
            -v total_cpu_diff="${total_cpu_diffs[0]}" \
            -v cpu_cores="${cpu_cores}" \
            'BEGIN { printf("%.0f", used_cpu_diff / total_cpu_diff * 100 * cpu_cores) }'
        )" \
        "$(( 100 * cpu_cores))" \
        "{{ horizontal_progress_bar(${used_cpu_diffs[0]}, 0, ${total_cpu_diffs[0]}, true) }}"
    for (( i = 1; i < ${#used_cpu_diffs[@]}; ++i )); do
        printf "%s;;;" "{{ vertical_progress_bar(${used_cpu_diffs[$i]}, 0, ${total_cpu_diffs[$i]}, true) }}"
    done
}

print_ram_and_swap_usage_linux () {
    local used_ram total_ram used_swap total_swap

    read -r used_ram total_ram < <(free -b | awk -F'[:[:space:]]+' '$1 == "Mem" { printf("%d %d", $3, $2); exit }')
    read -r used_swap total_swap < <(free -b | awk -F'[:[:space:]]+' '$1 == "Swap" { printf("%d %d", $3, $2); exit }')

    echo "RAM and Swap usage"
    printf "RAM: %s / %s %s;;" \
        "$(bytes_to_human_size "${used_ram}")" \
        "$(bytes_to_human_size "${total_ram}")" \
        "{{ horizontal_progress_bar(${used_ram}, 0, ${total_ram}, true) }}"
    printf "Swap: %s / %s %s\n" \
        "$(bytes_to_human_size "${used_swap}")" \
        "$(bytes_to_human_size "${total_swap}")" \
        "{{ horizontal_progress_bar(${used_swap}, 0, ${total_swap}, true) }}"
}

print_filesystem_usage_linux () {
    local mount_point used_bytes total_bytes

    echo "Filesystem usage"
    while read -r mount_point used_bytes total_bytes; do
        printf "%s: %s / %s %s;;" \
        "${mount_point}" \
        "$(bytes_to_human_size "${used_bytes}")" \
        "$(bytes_to_human_size "${total_bytes}")" \
        "{{ horizontal_progress_bar(${used_bytes}, 0, ${total_bytes}, true) }}"
    done < <(df -Pl -B 1 | awk '$1 ~ "^/dev" { printf("%s %d %d\n", $6, $3, $2) }')
}

display_infos () {
    local all_infos descriptions info_texts info_func current_info max_desc_len i description info_text

    all_infos=( "${INFOS[@]}" "${TWO_PASS_INFOS[@]}" )
    descriptions=()
    info_texts=()

    init_script_tmp_dir || return

    {
        for info_func in "${TWO_PASS_INFOS[@]}"; do
            ${info_func}
        done
        # Sleep a short amount of time to improve the measurement of the cpu usage
        sleep 1
        for info_func in "${all_infos[@]}"; do
            current_info="$(${info_func})"
            descriptions+=( "$(awk 'NR == 1' <<< "${current_info}")" )
            info_texts+=( "$(awk 'NR > 1' <<< "${current_info}")" )
        done

        max_desc_len="$(max_string_length "${descriptions[@]}")"

        for (( i = 0; i < ${#descriptions[@]}; ++i )); do
            description="${descriptions[$i]}"
            info_text="${info_texts[$i]}"
            printf "%+${max_desc_len}s:" "${description}"
            print_info_text "$(( max_desc_len + 1 ))" "$(get_terminal_width)" "${info_text}"
        done
    } > "${SCRIPT_TMP_DIR}/infos.out" && \
    cat "${SCRIPT_TMP_DIR}/infos.out"
}
