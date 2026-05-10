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

    if ! stage_is_done post; then
        printf '[!] Post-install stage did not complete.\n' >&2;
        printf '[!] Refusing to finalize installation.\n' >&2;

        return 1;
    fi

    dialog \
        --clear \
        --title " Finalization " \
        --infobox \
        "Applying final system configuration..." \
        5 50;

    if ! _finalize_sync; then
        printf '[!] Failed to sync filesystem buffers.\n' >&2;
        return 1;
    fi

    if ! _finalize_unmount; then
        printf '[!] Failed to unmount installation target.\n' >&2;
        return 1;
    fi

    stage_mark_done finalize;

    _finalize_success_dialog;
}