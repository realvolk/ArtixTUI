#!/usr/bin/env bash
set -eo pipefail;

_install_base() {
    local ucode;
    ucode=$(_get_cpu_ucode);
    local pkgs=("base" "base-devel" "linux-firmware" "${ucode}" "${INIT}" "elogind-${INIT}" "efibootmgr" "dhcpcd" "dhcpcd-${INIT}" "iwd" "iwd-${INIT}" "nano" "git" "dialog");

    [[ "${USER_SHELL}" == "/bin/zsh" ]] && pkgs+=("zsh" "zsh-completions");

    case "${KERNEL_CHOICE}" in
        "linux-lts")      pkgs+=("linux-lts" "linux-lts-headers") ;;
        "linux-hardened") pkgs+=("linux-hardened" "linux-hardened-headers") ;;
        "xanmod")         pkgs+=("linux-xanmod" "linux-xanmod-headers") ;;
        "tkg")            pkgs+=("linux" "linux-headers") ;;
        *)                pkgs+=("linux" "linux-headers") ;;
    esac;

    [[ "${BOOTLOADER}" == "grub" ]] && pkgs+=("grub" "os-prober");
    [[ "${BOOTLOADER}" == "refind" ]] && pkgs+=("refind");
    [[ "${FS_TYPE}" == "btrfs" ]] && pkgs+=("btrfs-progs");
    [[ "${USE_LUKS}" == "yes" ]] && pkgs+=("cryptsetup");
    _load_state 2>/dev/null || true;

    set +eo pipefail;

    {
        printf "[*] Validating keyrings...\n";
        pacman-key --init 2>&1;
        pacman-key --populate artix 2>&1;
        if grep -q "^\[universe\]" /etc/pacman.conf; then
            pacman-key --populate archlinux 2>&1;
        fi

        if [[ "${KERNEL_CHOICE}" == "xanmod" ]]; then
            printf "[*] Activating Arch Linux repositories for Xanmod...\n";
            pacman -Sy --noconfirm archlinux-keyring 2>&1;
            pacman-key --populate archlinux 2>&1;
        fi

        printf "[*] Starting basestrap installation...\n";
        (basestrap /mnt "${pkgs[@]}" --noconfirm --noprogressbar --color never 2>&1 || true) | \
            sed -u -E 's/\x1b\[[0-9;]*[a-zA-Z]//g';
            
        printf "\n[✓] Basestrap complete. Moving to final steps...\n";
        sleep 2;
    } | dialog --title " Base System Installation " --programbox 20 95;

    set -eo pipefail;
}

_prepare_handoff() {
    _load_state 2>/dev/null || true;

    printf "[*] Preparing post-install handoff...\n";

    cat <<EOF > /mnt/etc/install_config.conf
KERNEL_CHOICE="${KERNEL_CHOICE}"
WM_DE="${WM_DE}"
BOOTLOADER="${BOOTLOADER}"
INIT="${INIT}"
USER_NAME="${USER_NAME}"
USER_PASS="${USER_PASS}"
ROOT_PASS="${ROOT_PASS}"
USER_SHELL="${USER_SHELL}"
EOF
    chmod 600 /mnt/etc/install_config.conf
    local cores; cores=$(nproc);
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j${cores}\"/" /mnt/etc/makepkg.conf;

    if [[ -f "${SCRIPT_DIR}/../firstboot.sh" ]]; then
        install -Dm755 "${SCRIPT_DIR}/../firstboot.sh" /mnt/usr/local/bin/firstboot.sh;
        install -Dm755 "${SCRIPT_DIR}/../firstboot_trigger.sh" /mnt/etc/profile.d/firstboot.sh;

        cat <<EOF > /mnt/etc/profile.d/firstboot.sh
if [[ \$(id -u) -eq 0 ]]; then
    /usr/local/bin/firstboot.sh
fi
EOF
    fi

    sync;
    printf "[✓] Handoff ready.\n";
}