#!/usr/bin/env bash
set -Eeuo pipefail;

stage_chroot() {
    if stage_is_done chroot; then
        printf '[*] Chroot stage already completed. Skipping...\n';
        return 0;
    fi;

    local init;

    init="$(state_get INIT openrc)";

    case "${init}" in
        openrc|runit|dinit|s6)
            ;;
        *)
            die "invalid init system: ${init}";
            ;;
    esac;

    printf '[*] Installing init system: %s\n' "${init}";

    artix-chroot /mnt pacman -S --noconfirm "${init}";

    configure_users;
    configure_bootloader;
    prepare_handoff;

    stage_mark_done chroot;
}