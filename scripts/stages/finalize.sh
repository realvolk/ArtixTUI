#!/usr/bin/env bash
set -Eeuo pipefail;

_finalize_sync() {
    sync;
}

_finalize_unmount() {
    umount -R /mnt 2>/dev/null || true;

    if [[ -e /dev/mapper/cryptroot ]]; then
        cryptsetup close cryptroot \
            2>/dev/null || true;
    fi;
}

_finalize_success_dialog() {
    dialog \
        --clear \
        --title " Installation Complete " \
        --msgbox \
        "Artix installation completed successfully.\n\nYou may now reboot." \
        8 60;
}

stage_finalize() {
    if stage_should_skip finalize; then
        printf '[*] Finalize stage already completed. Skipping...\n';
        return 0;
    fi;

    dialog \
        --clear \
        --title " Finalization " \
        --infobox \
        "Applying final system configuration..." \
        5 50;

    _finalize_sync;
    _finalize_unmount;
    _finalize_success_dialog;

    stage_mark_done finalize;
}