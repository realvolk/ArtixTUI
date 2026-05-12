#!/usr/bin/env bash
set -Eeuo pipefail;

stage_preflight() {
    if stage_should_skip preflight; then
        return 0;
    fi;

    require_root;
    require_efi;
    require_internet;

    local pkgs=();
    local fs_type;
    fs_type="$(state_get FS_TYPE ext4)";

    command_exists dialog      || pkgs+=(dialog);
    command_exists sgdisk      || pkgs+=(gptfdisk);
    command_exists cryptsetup  || pkgs+=(cryptsetup);
    command_exists mkfs.fat    || pkgs+=(dosfstools);
    command_exists lsblk       || pkgs+=(util-linux);
    command_exists wipefs      || pkgs+=(util-linux);
    command_exists btrfs       || pkgs+=(btrfs-progs);

    case "${fs_type}" in
        xfs)
            command_exists mkfs.xfs \
                || pkgs+=(xfsprogs);
            ;;

        f2fs)
            command_exists mkfs.f2fs \
                || pkgs+=(f2fs-tools);
            ;;

        exfat)
            command_exists mkfs.exfat \
                || pkgs+=(exfatprogs);
            ;;

        bcachefs)
            command_exists mkfs.bcachefs \
                || pkgs+=(bcachefs-tools);
            ;;

        zfs)
            command_exists zpool \
                || die 'zfs tools are unavailable in the live environment';
            ;;
    esac

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        {
            printf '[*] Installing required tools...\n';

            pacman -Sy \
                --noconfirm \
                --needed \
                "${pkgs[@]}";

            printf '\n[*] Preflight dependencies installed.\n';
        } 2>&1 | dialog \
            --clear \
            --title " Preflight " \
            --programbox 20 85;
    fi;

    stage_mark_done preflight;
}