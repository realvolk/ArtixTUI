#!/usr/bin/env bash
set -Eeuo pipefail;

stage_post() {
    if stage_should_skip post; then
        printf '[*] Post-install stage already completed. Skipping...\n';
        return 0;
    fi;

    local init;
    local network_stack;
    local wm_de;
    local x_stack;
    local kernel_choice;
    local audio_stack;
    local extras;
    local log_file;
    local rc=0;

    init="$(state_get INIT)";
    network_stack="$(state_get NETWORK_STACK)";
    wm_de="$(state_get WM_DE)";
    x_stack="$(state_get X_STACK xorg)";
    kernel_choice="$(state_get KERNEL_CHOICE linux)";
    audio_stack="$(state_get AUDIO_STACK pipewire)";
    extras="$(state_get EXTRAS '')";

    log_file='/tmp/post-stage.log';

    {
        printf '[*] Preparing installer environment...\n';

        mkdir -p /mnt/root;
        rm -rf /mnt/root/ArtixTUI;
        cp -r . /mnt/root/ArtixTUI;

        printf '[*] Entering chroot environment...\n';

        if ! artix-chroot /mnt /bin/bash <<EOF
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
source ./scripts/install/services.sh
source ./scripts/post/drivers.sh
source ./scripts/post/networking.sh
source ./scripts/post/desktop.sh
source ./scripts/post/audio.sh
source ./scripts/post/extras.sh

printf '[*] Configuring networking...\n'
setup_networking

printf '[*] Installing drivers...\n'
install_drivers

printf '[*] Installing desktop environment...\n'
install_desktop

printf '[*] Configuring audio...\n'
setup_audio

printf '[*] Installing extras...\n'
install_extras

printf '\n[✓] Post-install configuration complete.\n'
EOF
        then
            rc=$?
            printf '\n[!] Post-install stage failed with exit code: %s\n' "${rc}"
        fi

    } 2>&1 | tee "${log_file}" | dialog \
        --clear \
        --title " Post Installation " \
        --programbox 22 90;

    if [[ ${rc} -ne 0 ]]; then
        if [[ -f /mnt/root/ArtixTUI/drivers-debug.log ]]; then
            cp \
                /mnt/root/ArtixTUI/drivers-debug.log \
                /tmp/drivers-debug.log \
                2>/dev/null \
                || true;
        fi

        tui_msg \
            " Post Installation Failed " \
            "The post-install stage failed.

Logs:
- ${log_file}
- /tmp/drivers-debug.log

The installation was NOT marked complete.";

        return "${rc}";
    fi

    stage_mark_done post;
}