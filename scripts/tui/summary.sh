#!/usr/bin/env bash
set -Eeuo pipefail;

tui_show_summary() {
    local summary='';

    summary+="Disk: $(state_get DISK)\n";
    summary+="Filesystem: $(state_get FS_TYPE ext4)\n";
    summary+="Init: $(state_get INIT)\n";
    summary+="Bootloader: $(state_get BOOTLOADER grub)\n";
    summary+="Kernel: $(state_get KERNEL_CHOICE linux)\n";
    summary+="Desktop: $(state_get WM_DE none)\n";
    summary+="Network: $(state_get NETWORK_STACK)\n";
    summary+="X Stack: $(state_get X_STACK)\n";
    summary+="LUKS: $(state_get USE_LUKS no)\n";
    summary+="Arch Repos: $(state_get ENABLE_ARCH_REPOS no)\n";

    dialog \
        --clear \
        --title " Installation Summary " \
        --msgbox "${summary}" \
        18 70;
}