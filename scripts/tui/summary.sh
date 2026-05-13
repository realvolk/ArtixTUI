#!/usr/bin/env bash
set -Eeuo pipefail

tui_show_summary() {
    local summary
    printf -v summary \
"$(gum style --bold 'Disk:')       %s
$(gum style --bold 'Hostname:')   %s
$(gum style --bold 'Timezone:')   %s
$(gum style --bold 'Locale:')     %s
$(gum style --bold 'Keyboard:')   %s
$(gum style --bold 'Microcode:')  %s
$(gum style --bold 'BTRFS:')      %s
$(gum style --bold 'Filesystem:') %s
$(gum style --bold 'Init:')       %s
$(gum style --bold 'Bootloader:') %s
$(gum style --bold 'Kernel:')     %s
$(gum style --bold 'Desktop:')    %s
$(gum style --bold 'Network:')    %s
$(gum style --bold 'X Stack:')    %s
$(gum style --bold 'LUKS:')       %s
$(gum style --bold 'Arch Repos:') %s" \
        "$(state_get DISK)" \
        "$(state_get HOSTNAME artix)" \
        "$(state_get TIMEZONE Europe/Belgrade)" \
        "$(state_get LOCALE en_US.UTF-8)" \
        "$(state_get KEYMAP us)" \
        "$(state_get MICROCODE_OVERRIDE auto)" \
        "$(state_get BTRFS_LAYOUT standard)" \
        "$(state_get FS_TYPE ext4)" \
        "$(state_get INIT openrc)" \
        "$(state_get BOOTLOADER grub)" \
        "$(state_get KERNEL_CHOICE linux)" \
        "$(state_get WM_DE none)" \
        "$(state_get NETWORK_STACK dhcpcd+iwd)" \
        "$(state_get X_STACK xorg)" \
        "$(state_get USE_LUKS no)" \
        "$(state_get ENABLE_ARCH_REPOS no)"

    gum style --border rounded --padding 1 --bold "Installation Summary"
    gum format "${summary}"
    gum confirm "Proceed with installation?" || exit 0
}