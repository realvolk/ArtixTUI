#!/usr/bin/env bash
set -Eeuo pipefail;

create_filesystems() {
    local disk;
    local fs_type;
    local swap_enabled;
    local kernel_choice;
    local kernel_headers='linux-headers';

    disk="$(state_get DISK)";
    fs_type="$(state_get FS_TYPE)";
    swap_enabled="$(state_get SWAP_ENABLED no)";
    kernel_choice="$(state_get KERNEL_CHOICE linux)";

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

    case "${kernel_choice}" in
        linux)
            kernel_headers='linux-headers'
            ;;

        linux-lts)
            kernel_headers='linux-lts-headers'
            ;;

        linux-hardened)
            kernel_headers='linux-hardened-headers'
            ;;

        linux-zen)
            kernel_headers='linux-zen-headers'
            ;;

        linux-cachy|linux-cachyos)
            if pacman -Si linux-cachyos-headers \
                >/dev/null 2>&1; then

                kernel_headers='linux-cachyos-headers'
            elif pacman -Si linux-cachy-headers \
                >/dev/null 2>&1; then

                kernel_headers='linux-cachy-headers'
            fi
            ;;

        xanmod)
            kernel_headers='linux-xanmod-headers'
            ;;
    esac

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

                modprobe f2fs >/dev/null 2>&1 || true;
                ;;

            exfat)
                pacman -Sy --needed --noconfirm exfatprogs;

                modprobe exfat >/dev/null 2>&1 || true;
                ;;
        esac

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
                    if tui_yesno \
                        " Bcachefs Support " \
                        "Bcachefs tools are not currently installed.\n\nTry installing them now?"; then

                        printf '[*] Attempting to install Bcachefs tools...\n';

                        pacman -Sy --noconfirm bcachefs-tools \
                            || pacman -Sy --noconfirm bcachefs-tools-git \
                            || true;
                    fi
                fi

                if ! command -v mkfs.bcachefs >/dev/null 2>&1; then
                    dialog \
                        --title " Bcachefs Unsupported " \
                        --msgbox \
"Unable to install Bcachefs tools in the current live environment.

Please use an ISO with Bcachefs support,
or choose another filesystem." \
                        10 70;

                    return 1;
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
                    dkms \
                    "${kernel_headers}" \
                    zfs-dkms \
                    zfs-utils;

                printf '[*] Creating ZFS pool...\n';

                zpool labelclear -f "${root_part}" \
                    >/dev/null 2>&1 || true;

                dkms install \
                    zfs/"$(pacman -Q zfs-dkms | awk '{print $2}')" \
                    || true;

                modprobe zfs;

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