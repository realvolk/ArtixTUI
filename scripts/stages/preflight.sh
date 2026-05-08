#!/usr/bin/env bash
set -Eeuo pipefail;

stage_preflight() {
    if stage_is_done preflight; then
        printf '[*] Preflight stage already completed. Skipping...\n';
        return 0;
    fi;

    require_root;
    require_efi;
    require_internet;

    local pkgs=();

    command_exists dialog      || pkgs+=(dialog);
    command_exists sgdisk      || pkgs+=(gptfdisk);
    command_exists cryptsetup  || pkgs+=(cryptsetup);
    command_exists mkfs.fat    || pkgs+=(dosfstools);
    command_exists lsblk       || pkgs+=(util-linux);
    command_exists wipefs      || pkgs+=(util-linux);
    command_exists btrfs       || pkgs+=(btrfs-progs);

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