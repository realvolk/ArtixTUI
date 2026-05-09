#!/usr/bin/env bash
set -Eeuo pipefail;

create_filesystems() {
    local disk;
    local fs_type;
    local swap_enabled;

    disk="$(state_get DISK)";
    fs_type="$(state_get FS_TYPE)";
    swap_enabled="$(state_get SWAP_ENABLED no)";

    local efi_part;
    local swap_part='';
    local root_part;

    efi_part=$(get_partition_name "${disk}" 1);

    if [[ "${swap_enabled}" == 'yes' ]]; then
        swap_part=$(get_partition_name "${disk}" 2);
        root_part=$(get_partition_name "${disk}" 3);
    else
        root_part=$(get_partition_name "${disk}" 2);
    fi

    {
        printf '[*] Formatting EFI partition...\n';

        mkfs.fat -F32 "${efi_part}";

        if [[ "${swap_enabled}" == 'yes' ]]; then
            printf '[*] Initializing swap...\n';

            mkswap "${swap_part}";
            swapon "${swap_part}";
        fi

        case "${fs_type}" in
            btrfs)
                printf '[*] Creating BTRFS filesystem...\n';

                mkfs.btrfs -f "${root_part}";
                ;;

            ext4)
                printf '[*] Creating EXT4 filesystem...\n';

                mkfs.ext4 -F "${root_part}";
                ;;

            xfs)
                printf '[*] Creating XFS filesystem...\n';

                mkfs.xfs -f "${root_part}";
                ;;

            f2fs)
                printf '[*] Creating F2FS filesystem...\n';

                mkfs.f2fs -f "${root_part}";
                ;;

            bcachefs)
                printf '[*] Ensuring Bcachefs tools are installed...\n';

                if ! command -v mkfs.bcachefs >/dev/null 2>&1; then
                    pacman -Sy --noconfirm bcachefs-tools;
                fi

                printf '[*] Creating Bcachefs filesystem...\n';

                mkfs.bcachefs -f "${root_part}";
                ;;

            exfat)
                printf '[*] Creating exFAT filesystem...\n';

                mkfs.exfat "${root_part}";
                ;;

            zfs)
                printf '[*] Setting up OpenZFS repository...\n';

                if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf

[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
                fi

                pacman-key --init;
                pacman-key --populate artix;

                pacman-key \
                    --recv-keys F75D9D76 \
                    --keyserver keyserver.ubuntu.com;

                pacman-key \
                    --lsign-key F75D9D76;

                pacman -Sy --noconfirm;

                printf '[*] Installing ZFS utilities...\n';

                pacman -S --noconfirm \
                    zfs-utils;

                printf '[*] Creating ZFS pool...\n';

                modprobe zfs || true;

                zpool create \
                    -f \
                    -o ashift=12 \
                    -O compression=zstd \
                    -O atime=off \
                    -O mountpoint=none \
                    zroot "${root_part}";

                zfs create -o mountpoint=/ zroot/root;
                ;;
        esac

        printf '\n[*] Filesystem creation complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Filesystems " \
        --programbox 20 85;
}