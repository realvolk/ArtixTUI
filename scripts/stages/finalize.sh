#!/usr/bin/env bash
set -Eeuo pipefail

_finalize_sync() {
    sync
}

_finalize_cleanup_installer_state() {
    if [[ -f /mnt/etc/artix-installer.conf ]]; then
        shred -u /mnt/etc/artix-installer.conf 2>/dev/null || rm -f /mnt/etc/artix-installer.conf
    fi
}

_finalize_unmount() {
    umount -R /mnt 2>/dev/null || true
    if [[ -e /dev/mapper/cryptroot ]]; then
        cryptsetup close cryptroot 2>/dev/null || true
    fi
}

_finalize_success_dialog() {
    gum style --border rounded --padding 1 --bold "Artix installation completed successfully!"
    gum style "You may now reboot."
    gum confirm "Press Enter to finish" --affirmative="OK" --timeout=0 2>/dev/null || true
}

stage_finalize() {
    if stage_should_skip finalize; then return 0; fi
    if ! stage_is_done post; then
        log_error "Post-install stage did not complete. Refusing to finalize."
        return 1
    fi

    log_info "Applying final system configuration..."
    if ! _finalize_sync; then
        log_error "Failed to sync filesystem buffers."
        return 1
    fi
    if ! _finalize_cleanup_installer_state; then
        log_error "Failed to clean installer state."
        return 1
    fi
    if ! _finalize_unmount; then
        log_error "Failed to unmount installation target."
        return 1
    fi

    stage_mark_done finalize
    _finalize_success_dialog
}