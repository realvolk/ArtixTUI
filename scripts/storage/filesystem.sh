#!/usr/bin/env bash
set -Eeuo pipefail;

create_filesystems() {
    local disk;
    local fs_type;
    local swap_enabled;

    disk="$(state_get DISK)";

    [[ -b "${disk}" ]] \
        || die "invalid disk: ${disk}";

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

    [[ "${efi_part}" =~ ^${disk} ]] \
        || die "EFI partition does not belong to selected disk";

    [[ "${root_part}" =~ ^${disk} ]] \
        || die "Root partition does not belong to selected disk";

    {
        printf '[*] Ensuring EFI filesystem support...\n';

        pacman -Sy --needed --noconfirm dosfstools;

        modprobe fat >/dev/null 2>&1 || true;
        modprobe vfat >/dev/null 2>&1 || true;

        case "${fs_type}" in
            btrfs)
                pacman -Sy --needed --noconfirm btrfs-progs;

                modprobe btrfs >/dev/null 2>&1 || true;
                ;;

            ext4)
                pacman -Sy --needed --noconfirm e2fsprogs;

                modprobe ext4 >/dev/null 2>&1 || true;
                ;;

            xfs)
                pacman -Sy --needed --noconfirm xfsprogs;

                modprobe xfs >/dev/null 2>&1 || true;
                ;;

            f2fs)
                pacman -Sy --needed --noconfirm f2fs-tools;

                command -v mkfs.f2fs >/dev/null 2>&1 \
                    || die 'mkfs.f2fs is unavailable';

                modprobe f2fs >/dev/null 2>&1 || true;
                ;;

            bcachefs)
                printf '[*] Ensuring Bcachefs tools are installed...\n';

                if ! command -v mkfs.bcachefs >/dev/null 2>&1; then
                    pacman -Sy --needed --noconfirm \
                        bcachefs-tools \
                        >/dev/null 2>&1 || true;
                fi

                command -v mkfs.bcachefs >/dev/null 2>&1 \
                    || die 'mkfs.bcachefs is unavailable';

                modprobe bcachefs >/dev/null 2>&1 || true;
                ;;

            exfat)
                pacman -Sy --needed --noconfirm exfatprogs;

                modprobe exfat >/dev/null 2>&1 || true;
                ;;

            zfs)
                printf '[*] Verifying ZFS support...\n';

                command -v zpool >/dev/null 2>&1 \
                    || die 'zpool command is unavailable';

                if ! modprobe zfs >/dev/null 2>&1; then
                    dialog \
                        --title " ZFS Unsupported " \
                        --msgbox \
"Failed to load the ZFS kernel module.

The current live environment does not support ZFS.

Please use a ZFS-capable ISO/kernel." \
                        10 70;

                    return 1;
                fi
                ;;
        esac

        printf '[*] Formatting EFI partition...\n';

        mkfs.fat -F32 "${efi_part}" \
            || die 'failed to create FAT32 EFI filesystem';

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
                printf '[*] Creating Bcachefs filesystem...\n';

                mkfs.bcachefs \
                    --force \
                    "${root_part}";
                ;;

            exfat)
                printf '[*] Creating exFAT filesystem...\n';

                mkfs.exfat "${root_part}";
                ;;

            zfs)
                printf '[*] Clearing old ZFS labels...\n';

                zpool labelclear -f "${root_part}" \
                    >/dev/null 2>&1 || true;

                wipefs -af "${root_part}" \
                    >/dev/null 2>&1 || true;

                printf '[*] Creating ZFS pool...\n';

                zpool create \
                    -f \
                    -o ashift=12 \
                    -O compression=zstd \
                    -O atime=off \
                    -O mountpoint=none \
                    zroot "${root_part}";

                zfs create \
                    -o mountpoint=/ \
                    zroot/root;
                ;;
        esac

        printf '\n[*] Filesystem creation complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Filesystems " \
        --programbox 20 85;
}