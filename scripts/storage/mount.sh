#!/usr/bin/env bash
set -Eeuo pipefail;

mount_filesystems() {
    local disk;
    local fs_type;
    local swap_enabled;
    local bootloader;

    disk="$(state_get DISK)";
    fs_type="$(state_get FS_TYPE)";
    swap_enabled="$(state_get SWAP_ENABLED no)";
    bootloader="$(state_get BOOTLOADER grub)";

    local efi_part;
    local root_part;
    local efi_mount='/mnt/boot/efi';

    efi_part=$(get_partition_name "${disk}" 1);

    if [[ "${swap_enabled}" == 'yes' ]]; then
        root_part=$(get_partition_name "${disk}" 3);
    else
        root_part=$(get_partition_name "${disk}" 2);
    fi

    if [[ "${bootloader}" == 'efistub' ]]; then
        efi_mount='/mnt/boot'
    fi

    {
        case "${fs_type}" in
            btrfs)
                modprobe btrfs >/dev/null 2>&1 || true;
                ;;

            ext4)
                modprobe ext4 >/dev/null 2>&1 || true;
                ;;

            xfs)
                modprobe xfs >/dev/null 2>&1 || true;
                ;;

            f2fs)
                modprobe f2fs >/dev/null 2>&1 || true;
                ;;

            exfat)
                modprobe exfat >/dev/null 2>&1 || true;
                ;;
        esac

        modprobe vfat >/dev/null 2>&1 || true;

        printf '[*] Mounting root filesystem...\n';

        case "${fs_type}" in
            btrfs)
                mount "${root_part}" /mnt;

                printf '[*] Creating BTRFS subvolumes...\n';

                for subvol in \
                    @ \
                    @home \
                    @log \
                    @pkg \
                    @snapshots; do

                    if ! btrfs subvolume list /mnt \
                        | awk '{print $NF}' \
                        | grep -qx "${subvol}"; then

                        btrfs subvolume create "/mnt/${subvol}";
                    fi
                done

                umount /mnt;

                mount -o noatime,compress=zstd,subvol=@ \
                    "${root_part}" /mnt;

                mount --mkdir \
                    -o noatime,compress=zstd,subvol=@home \
                    "${root_part}" /mnt/home;

                mount --mkdir \
                    -o noatime,compress=zstd,subvol=@log \
                    "${root_part}" /mnt/var/log;

                mount --mkdir \
                    -o noatime,compress=zstd,subvol=@pkg \
                    "${root_part}" /mnt/var/cache/pacman/pkg;

                mount --mkdir \
                    -o noatime,compress=zstd,subvol=@snapshots \
                    "${root_part}" /mnt/.snapshots;
                ;;

            zfs)
                zpool export zroot 2>/dev/null || true;

                zpool import \
                    -R /mnt \
                    zroot;

                zfs mount zroot/root;
                ;;

            ext4|xfs|f2fs|bcachefs|exfat)
                mount -t "${fs_type}" "${root_part}" /mnt;
                ;;

            *)
                die "unsupported filesystem: ${fs_type}";
                ;;
        esac

        printf '[*] Mounting EFI partition...\n';

        mount -t vfat --mkdir \
            "${efi_part}" \
            "${efi_mount}";

        printf '\n[*] Mount setup completed.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Mount Setup " \
        --programbox 20 85;
}