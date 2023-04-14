# shellcheck shell=bash

INFOS=( \
    "print_os_info_linux" \
    "print_uptime_info_linux" \
    "print_shell_info_linux" \
    "print_cpu_info_linux" \
    "print_gpu_info_linux" \
    "print_ram_and_swap_usage_linux" \
    "print_filesystem_usage_linux" \
)

TWO_PASS_INFOS=( \
    "print_cpu_usage_linux" \
)

print_os_info_linux () {
    local prefer_lsb

    if [[ -f /etc/arch-release ]] || [[ ! -r /etc/os-release ]]; then
        # `lsb_release` gives more details on Arch-based distributions
        prefer_lsb=1
    else
        prefer_lsb=0
    fi

    echo "Operating system"
    if command_available lsb_release && (( prefer_lsb )); then
        printf "%s %s (%s);;" \
            "$(lsb_release -d | awk -F':[ \t]+' '{ print $2 }')" \
            "$(lsb_release -r | awk -F':[ \t]+' '{ print $2 }')" \
            "$(lsb_release -c | awk -F':[ \t]+' '{ print $2 }')"
    elif [[ -r "/etc/os-release" ]]; then
        awk \
            -F'=' \
            '{ gsub(/"/, "", $2); info[$1]=$2 } END { printf("%s %s;;", info["NAME"], info["VERSION"]) }' \
            /etc/os-release
    fi
    echo "Linux kernel $(uname -r)"
}

print_uptime_info_linux () {
    command_available uptime || return
    echo "Uptime"
    uptime | awk -F',[ \t]*' '{sub(/.*up\s*/, "", $1); print $1 }'
}

print_shell_info_linux () {
    [[ -n "${SHELL}" ]] || return
    echo "Shell"
    "${SHELL}" --version | head -1
}

print_cpu_info_linux () {
    local cpu_model core_count thread_count socket_count

    cpu_model="$(awk -F'[ \t]+:[ \t]+' '$1 == "model name" { print $2; exit }' /proc/cpuinfo)"
    socket_count="$( \
        awk -F'[ \t]+:[ \t]+' '$1 == "physical id" && !a[$2]++ { ++sockets } END { print sockets }' /proc/cpuinfo \
    )"
    core_count="$(awk -F'[ \t]+:[ \t]+' '$1 == "core id" && !a[$2]++ { ++cores } END { print cores }' /proc/cpuinfo)"
    thread_count="$(awk -F'[ \t]+:[ \t]+' '$1 == "core id" { ++threads } END { print threads }' /proc/cpuinfo)"

    echo "CPU"
    echo "${cpu_model}, ${socket_count} sockets, ${core_count} cores, ${thread_count} threads"
}

print_gpu_info_linux () {
    _gpu_info_general () {
        local lscpi_vga_output card_name pci_address card_ram

        command_available lspci || return

        lscpi_vga_output="$(lspci | grep '\bVGA\b')"
        card_name="$(awk -F':[ \t]+' '{ print $2 }' <<< "${lscpi_vga_output}")"
        pci_address="$(awk '{ print $1 }' <<< "${lscpi_vga_output}")"
        card_ram="$(lspci -s "${pci_address}" -v | grep ' prefetchable\b' | awk -F'size=|]' '{ print $2 }')"

        echo "GPU"
        echo "${card_name}, ${card_ram} RAM"
    }

    _gpu_info_nvidia () {
        local nvidia_card_pci_addresses pci_address gpu_models gpu_model

        nvidia_card_pci_addresses=()
        if [[ -d "/proc/driver/nvidia/gpus" ]]; then
            mapfile -t nvidia_card_pci_addresses < <(ls /proc/driver/nvidia/gpus)
        fi

        gpu_models=()
        for pci_address in "${nvidia_card_pci_addresses[@]}"; do
            gpu_model="$(awk \
                -F':[ \t]+' \
                '$1 == "Model" { print $2; exit }' \
                "/proc/driver/nvidia/gpus/${pci_address}/information" \
            )"
            if [[ -n "${gpu_model}" ]]; then
                gpu_models+=("${gpu_model}")
            fi
        done
        if (( "${#gpu_models[@]}" > 0 )); then
            if (( "${#gpu_models[@]}" == 1 )); then
                echo "Dedicated GPU"
            else
                echo "Dedicated GPUs"
            fi
            for gpu_model in "${gpu_models[@]}"; do
                echo "${gpu_model}"
            done
        else
            return 1
        fi
    }

    # TODO: Detect more dedicated GPU chips
    _gpu_info_nvidia || \
    _gpu_info_general
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

    if (( total_cpu_diffs[0] == 0 )); then
        >&2 echo "Could not determine the CPU usage. Your awk implementation probably cannot handle large integers."
        return 1
    fi

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

    command_available free || return

    read -r used_ram total_ram < <(free -k | awk -F'[:[:space:]]+' '$1 == "Mem" { printf("%d %d", $3, $2); exit }')
    read -r used_swap total_swap < <(free -k | awk -F'[:[:space:]]+' '$1 == "Swap" { printf("%d %d", $3, $2); exit }')

    echo "RAM and Swap usage"
    printf "RAM: %s / %s %s;;" \
        "$(bytes_to_human_size "${used_ram}")" \
        "$(bytes_to_human_size "${total_ram}")" \
        "{{ horizontal_progress_bar(${used_ram}, 0, ${total_ram}, true) }}"
    if (( total_swap > 0 )); then
        printf "Swap: %s / %s %s\n" \
            "$(bytes_to_human_size "${used_swap}")" \
            "$(bytes_to_human_size "${total_swap}")" \
            "{{ horizontal_progress_bar(${used_swap}, 0, ${total_swap}, true) }}"
    fi
}

print_filesystem_usage_linux () {
    local at_least_one_mount_point mount_point used_bytes total_bytes

    echo "Filesystem usage"
    at_least_one_mount_point=0
    while read -r mount_point used_bytes total_bytes; do
        printf "%s: %s / %s %s;;" \
        "${mount_point}" \
        "$(bytes_to_human_size "${used_bytes}")" \
        "$(bytes_to_human_size "${total_bytes}")" \
        "{{ horizontal_progress_bar(${used_bytes}, 0, ${total_bytes}, true) }}"
        at_least_one_mount_point=1
    done < <(df -Pkl | awk '$1 ~ "^/dev" { printf("%s %d %d\n", $6, $3, $2) }')

    (( at_least_one_mount_point ))
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
            current_info="$(${info_func})" || continue
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
