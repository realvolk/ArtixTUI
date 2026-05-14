#!/usr/bin/env bash
set -Eeuo pipefail

stage_post() {
    if stage_should_skip post; then return 0; fi

    local init network_stack wm_de x_stack kernel_choice audio_stack extras log_file rc=0
    init="$(state_get INIT)"
    network_stack="$(state_get NETWORK_STACK)"
    wm_de="$(state_get WM_DE)"
    x_stack="$(state_get X_STACK xorg)"
    kernel_choice="$(state_get KERNEL_CHOICE linux)"
    audio_stack="$(state_get AUDIO_STACK pipewire)"
    extras="$(state_get EXTRAS '')"
    log_file='/tmp/post-stage.log'

    log_info "Preparing installer environment..."
    mkdir -p /mnt/root
    rm -rf /mnt/root/ArtixTUI
    cp -r . /mnt/root/ArtixTUI

    log_info "Entering chroot environment..."
    if artix-chroot /mnt /bin/bash <<EOF
set -Eeuo pipefail
export INIT="${init}"
export NETWORK_STACK="${network_stack}"
export WM_DE="${wm_de}"
export X_STACK="${x_stack}"
export KERNEL_CHOICE="${kernel_choice}"
export AUDIO_STACK="${audio_stack}"
export EXTRAS="${extras}"
cd /root/ArtixTUI || exit 1
source ./scripts/state.sh
source ./scripts/common.sh
source ./scripts/install/services.sh
source ./scripts/post/drivers.sh
source ./scripts/post/networking.sh
source ./scripts/post/desktop.sh
source ./scripts/post/audio.sh
source ./scripts/post/extras.sh
log_info() { printf '\e[1;34m[*] %s\e[0m\n' "\$*" | tee -a /var/log/artix-installer.log; }
log_info "Configuring networking..."
setup_networking
log_info "Installing drivers..."
install_drivers
log_info "Installing desktop environment..."
install_desktop
log_info "Configuring audio..."
setup_audio
log_info "Installing extras..."
install_extras
log_info "Post-install configuration complete."
EOF
    then
        rc=0
    else
        rc=$?
        log_error "Post-install stage failed with exit code: ${rc}"
    fi

    if [[ ${rc} -ne 0 ]]; then
        if [[ -f /mnt/root/ArtixTUI/drivers-debug.log ]]; then
            cp /mnt/root/ArtixTUI/drivers-debug.log /tmp/drivers-debug.log 2>/dev/null || true
        fi
        tui_msg "Post Installation Failed" \
            "The post-install stage failed.\n\nLogs:\n- ${log_file}\n- /tmp/drivers-debug.log\n\nThe installation was NOT marked complete."
        return ${rc}
    fi

    touch /mnt/root/.artix-post-complete
    stage_mark_done post
}