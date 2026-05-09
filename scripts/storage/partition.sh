#!/usr/bin/env bash
set -Eeuo pipefail;

partition_disk() {
    local disk;
    local swap_enabled='no';
    local swap_size='0';

    disk="$(state_get DISK)";

    [[ -n "${disk}" ]] \
        || die 'no disk selected';

    if tui_yesno \
        " Swap Partition " \
        "Would you like to create a swap partition?"; then

        swap_enabled='yes';

        local mem_gib;

        mem_gib=$(
            awk '/MemTotal/ {
                printf "%d", ($2 / 1024 / 1024) + 1
            }' /proc/meminfo
        );

        if [[ "${mem_gib}" -le 8 ]]; then
            swap_size='4G';
        elif [[ "${mem_gib}" -le 16 ]]; then
            swap_size='8G';
        else
            swap_size='16G';
        fi

        swap_size=$(
            tui_input \
                " Swap Size " \
                "Recommended swap size: ${swap_size}\n\nEnter desired swap size:" \
                "${swap_size}"
        );

        [[ -n "${swap_size}" ]] \
            || die 'invalid swap size';
    fi

    state_set SWAP_ENABLED "${swap_enabled}";
    state_set SWAP_SIZE "${swap_size}";

    {
        printf '[*] Unmounting previous mounts...\n';

        swapoff -a 2>/dev/null || true;
        umount -R /mnt 2>/dev/null || true;

        printf '[*] Cleaning old ZFS pools...\n';

        zpool export -a 2>/dev/null || true;

        printf '[*] Wiping existing filesystem signatures...\n';

        wipefs --all --force "${disk}";
        sgdisk --zap-all "${disk}";

        printf '[*] Clearing remaining partition metadata...\n';

        dd if=/dev/zero \
            of="${disk}" \
            bs=1M \
            count=32 \
            conv=fsync \
            status=none;

        blockdev --rereadpt "${disk}" 2>/dev/null || true;

        printf '[*] Creating GPT partition layout...\n';

        sgdisk -n 1:0:+1024M -t 1:ef00 "${disk}";

        if [[ "${swap_enabled}" == 'yes' ]]; then
            sgdisk -n 2:0:+"${swap_size}" -t 2:8200 "${disk}";
            sgdisk -n 3:0:0 -t 3:8300 "${disk}";
        else
            sgdisk -n 2:0:0 -t 2:8300 "${disk}";
        fi

        printf '[*] Informing kernel of partition changes...\n';

        if command -v partprobe &>/dev/null; then
            partprobe "${disk}";
        fi

        udevadm settle;

        sleep 2;

        printf '\n[*] Partitioning complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Partitioning " \
        --programbox 20 85;
}