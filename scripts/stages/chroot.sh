#!/usr/bin/env bash
set -Eeuo pipefail;

stage_chroot() {
    if stage_is_done chroot; then
        printf '[*] Chroot stage already completed. Skipping...\n';
        return 0;
    fi;

    local init;
    local rc=0;
    local bootloader;

    init="$(state_get INIT openrc)";
    bootloader="$(state_get BOOTLOADER grub)";

    case "${init}" in
        openrc|runit|dinit|s6)
            ;;
        *)
            die "invalid init system: ${init}";
            ;;
    esac;

    printf '[*] Installing init system: %s\n' "${init}";

    if ! artix-chroot /mnt pacman -S --noconfirm "${init}"; then
        rc=$?

        printf '[!] Failed to install init system: %s\n' \
            "${init}" \
            >&2;

        return "${rc}";
    fi

    if ! configure_users; then
        printf '[!] User configuration failed.\n' >&2;
        return 1;
    fi

    if ! configure_bootloader; then
        printf '[!] Bootloader configuration failed.\n' >&2;

        if [[ "${bootloader}" == 'efistub' ]]; then
            printf '[!] EFIStub boot entry creation failed.\n' >&2;
            printf '[!] Verify EFI mountpoints and kernel artifacts.\n' >&2;
            printf '[!] Check efibootmgr -v from the live environment.\n' >&2;
        fi

        return 1;
    fi

    if ! prepare_handoff; then
        printf '[!] Handoff preparation failed.\n' >&2;
        return 1;
    fi

    if [[ "${bootloader}" == 'efistub' ]]; then
        printf '[*] Validating EFI boot entries...\n';

        if ! artix-chroot /mnt efibootmgr -v \
            >/tmp/artix-efibootmgr.log 2>&1; then

            printf '[!] efibootmgr failed to read EFI entries.\n' >&2;
            printf '[!] System may not boot correctly.\n' >&2;

            return 1;
        fi

        if ! grep -qi \
            'Artix Linux' \
            /tmp/artix-efibootmgr.log; then

            printf '[!] No Artix EFI boot entry detected.\n' >&2;
            printf '[!] EFIStub configuration appears incomplete.\n' >&2;
            printf '[!] Review efibootmgr output manually.\n' >&2;

            return 1;
        fi

        printf '[*] EFI boot entry validation successful.\n';
    fi

    stage_mark_done chroot;
}