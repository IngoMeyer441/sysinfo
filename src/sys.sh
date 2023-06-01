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
    "print_nic_usage_linux" \
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
    local print_values current_used_cpu current_total_cpu used_cpu total_cpu i cpu_cores used_cpu_diffs total_cpu_diffs
    declare -ga previous_used_cpu previous_total_cpu

    print_values="$(( ${#previous_used_cpu[@]} ))"

    current_used_cpu=()
    current_total_cpu=()
    i=0
    while read -r used_cpu total_cpu; do
        current_used_cpu+=( "${used_cpu}" )
        current_total_cpu+=( "${total_cpu}" )
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

    if (( print_values )); then
        used_cpu_diffs=()
        total_cpu_diffs=()
        for (( i = 0; i < ${#current_used_cpu[@]}; ++i )); do
            used_cpu_diffs+=( \
                "$(awk \
                    -v current_used_cpu="${current_used_cpu[$i]}" \
                    -v previous_used_cpu="${previous_used_cpu[$i]}" \
                    'BEGIN { printf("%d\n", current_used_cpu - previous_used_cpu) }' \
                )" \
            )
            total_cpu_diffs+=( \
                "$(awk \
                    -v current_total_cpu="${current_total_cpu[$i]}" \
                    -v previous_total_cpu="${previous_total_cpu[$i]}" \
                    'BEGIN { printf("%d\n", current_total_cpu - previous_total_cpu) }' \
                )" \
            )
        done

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
    fi
    previous_used_cpu=( "${current_used_cpu[@]}" )
    previous_total_cpu=( "${current_total_cpu[@]}" )
}

print_ram_and_swap_usage_linux () {
    local used_ram total_ram used_swap total_swap

    command_available free || return

    read -r used_ram total_ram < <(free -k | awk -F'[:[:space:]]+' '$1 == "Mem" { printf("%d %d", $3, $2); exit }')
    read -r used_swap total_swap < <(free -k | awk -F'[:[:space:]]+' '$1 == "Swap" { printf("%d %d", $3, $2); exit }')

    echo "RAM and Swap usage"
    printf "RAM: %s / %s %s;;" \
        "$(kbytes_to_human_size "${used_ram}")" \
        "$(kbytes_to_human_size "${total_ram}")" \
        "{{ horizontal_progress_bar(${used_ram}, 0, ${total_ram}, true) }}"
    if (( total_swap > 0 )); then
        printf "Swap: %s / %s %s\n" \
            "$(kbytes_to_human_size "${used_swap}")" \
            "$(kbytes_to_human_size "${total_swap}")" \
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
        "$(kbytes_to_human_size "${used_bytes}")" \
        "$(kbytes_to_human_size "${total_bytes}")" \
        "{{ horizontal_progress_bar(${used_bytes}, 0, ${total_bytes}, true) }}"
        at_least_one_mount_point=1
    done < <(df -Pkl | awk '$1 ~ "^/dev" && $6 !~ "^/snap" { printf("%s %d %d\n", $6, $3, $2) }')

    (( at_least_one_mount_point ))
}

print_nic_usage_linux () {
    local current_net_timestamp print_values net_devices diff_timestamp current_rxs current_txs net_device rx tx speed
    local diff_rx_per_s diff_tx_per_s i
    declare -g previous_net_timestamp
    declare -ga previous_rxs previous_txs

    current_net_timestamp="${EPOCHREALTIME}"
    if [[ -z "${current_net_timestamp}" ]]; then
        current_net_timestamp="$(date '+%s')"
    fi
    print_values="$(( ${#previous_rxs[@]} ))"
    mapfile -t net_devices < <(ls /sys/class/net)

    (( "${#net_devices}" > 0 )) || return

    if (( print_values )); then
        echo "NIC usage"
        diff_timestamp="$( \
            awk \
                -v current_net_timestamp="${current_net_timestamp}" \
                -v previous_net_timestamp="${previous_net_timestamp}" \
                'BEGIN { printf("%lf\n", current_net_timestamp-previous_net_timestamp) }' \
        )"
    fi
    current_rxs=()
    current_txs=()
    i=0
    for net_device in "${net_devices[@]}"; do
        # Consider only physical network devices which are UP
        if [[ ! -d "/sys/class/net/${net_device}/device" ]] || \
            [[ "$(cat "/sys/class/net/${net_device}/carrier")" != "1" ]]; then
            continue
        fi
        # Use KiB as common unit
        rx="$(awk '{ printf("%d\n", $1 / 1024) }' < "/sys/class/net/${net_device}/statistics/rx_bytes")"
        tx="$(awk '{ printf("%d\n", $1 / 1024) }' < "/sys/class/net/${net_device}/statistics/tx_bytes")"
        speed=0
        if [[ -d "/sys/class/net/${net_device}/wireless" ]]; then
            speed="$(awk "\$1 == \"${net_device}:\" { printf(\"%d\n\", \$3 * 1024 / 8) }" < /proc/net/wireless)"
        else
            speed="$(awk '{ printf("%d\n", $1 * 1024 / 8) }' < "/sys/class/net/${net_device}/speed" 2>/dev/null)"
        fi
        if (( speed <= 0 )); then
            # Assume 100 MBit/s (= 12800 KiB/s) if speed cannot be determined
            speed=12800
        fi
        if (( print_values )); then
            diff_rx_per_s="$( \
                awk \
                    -v current_rx="${rx}" \
                    -v previous_rx="${previous_rxs[$i]}" \
                    -v diff_timestamp="${diff_timestamp}" \
                    'BEGIN { printf("%d\n", (current_rx-previous_rx)/diff_timestamp) }' \
                )"
            diff_tx_per_s="$( \
                awk \
                    -v current_tx="${tx}" \
                    -v previous_tx="${previous_txs[$i]}" \
                    -v diff_timestamp="${diff_timestamp}" \
                    'BEGIN { printf("%d\n", (current_tx-previous_tx)/diff_timestamp) }' \
                )"
            printf "%s: RX: %s/s / %s/s %s TX: %s/s / %s/s %s;;" \
                "${net_device}" \
                "$(kbytes_to_human_size "${diff_rx_per_s}")" \
                "$(kbytes_to_human_size "${speed}")" \
                "{{ horizontal_progress_bar(${diff_rx_per_s}, 0, ${speed}, true) }}" \
                "$(kbytes_to_human_size "${diff_tx_per_s}")" \
                "$(kbytes_to_human_size "${speed}")" \
                "{{ horizontal_progress_bar(${diff_tx_per_s}, 0, ${speed}, true) }}"
        fi
        current_rxs+=( "${rx}" )
        current_txs+=( "${tx}" )
        (( ++i ))
    done
    previous_net_timestamp="${current_net_timestamp}"
    previous_rxs=( "${current_rxs[@]}" )
    previous_txs=( "${current_txs[@]}" )
}

display_infos () {
    local all_infos descriptions info_texts first_run start_timestamp info_func current_info max_desc_len i description
    local info_text current_timestamp number_of_lines

    all_infos=( "${INFOS[@]}" "${TWO_PASS_INFOS[@]}" )

    init_script_tmp_dir || return

    first_run=1
    start_timestamp="$(date '+%s')"
    printf "%s" "${TERM_CURSOR_INVISIBLE}"
    while true; do
        descriptions=()
        info_texts=()
        {
            if (( first_run )); then
                for info_func in "${TWO_PASS_INFOS[@]}"; do
                    ${info_func}
                done
            fi
            # Sleep a short amount of time to improve the measurement of the cpu and nic usage
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
        if (( ! first_run )); then
            while (( number_of_lines > 0 )); do
                printf "%s" "${TERM_CURSOR_UP}"
                (( --number_of_lines ))
            done
            printf "\r"
        fi
        cat "${SCRIPT_TMP_DIR}/infos.out"
        first_run=0
        if (( CONTINUOUS_MODE )); then
            current_timestamp="$(date '+%s')"
            if (( CONTINUOUS_MODE_SECONDS > 0 )) && \
                (( current_timestamp - start_timestamp > CONTINUOUS_MODE_SECONDS )); then
                break
            fi
        else
            break
        fi
        number_of_lines="$(wc -l "${SCRIPT_TMP_DIR}/infos.out" | awk '{ print $1 }')"
    done
}
