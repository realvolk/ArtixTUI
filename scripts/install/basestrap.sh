#!/usr/bin/env bash
set -Eeuo pipefail

install_base_system() {
    local init kernel fs_type bootloader network_stack user_shell display_manager wm_de locale keymap timezone microcode_override

    init="$(state_get INIT)"
    kernel="$(state_get KERNEL_CHOICE linux)"
    fs_type="$(state_get FS_TYPE ext4)"
    bootloader="$(state_get BOOTLOADER grub)"
    network_stack="$(state_get NETWORK_STACK dhcpcd+iwd)"
    user_shell="$(state_get USER_SHELL bash)"
    display_manager="$(state_get DISPLAY_MANAGER none)"
    wm_de="$(state_get WM_DE none)"
    locale="$(state_get LOCALE en_US.UTF-8)"
    keymap="$(state_get KEYMAP us)"
    timezone="$(state_get TIMEZONE UTC)"
    microcode_override="$(state_get MICROCODE_OVERRIDE auto)"

    detect_kernel_package "${kernel}"

    local ucode='amd-ucode'
    grep -q 'GenuineIntel' /proc/cpuinfo && ucode='intel-ucode'

    case "${microcode_override}" in
        intel) ucode='intel-ucode' ;;
        amd)   ucode='amd-ucode' ;;
        none)  ucode='' ;;
    esac

    local pkgs=(
        base base-devel linux-firmware bash nano vim sudo
        git curl wget pciutils "${init}" dbus efibootmgr dosfstools
    )
    [[ -n "${ucode}" ]] && pkgs+=("${ucode}")

    case "${wm_de}" in
        hyprland|mango|niri|sway)
            pkgs+=(seatd "seatd-${init}") ;;
        *)
            pkgs+=("elogind-${init}") ;;
    esac

    case "${user_shell}" in
        bash) ;;
        zsh)  pkgs+=(zsh) ;;
        fish) pkgs+=(fish) ;;
        *)    die "unsupported shell: ${user_shell}" ;;
    esac

    case "${kernel}" in
        linux)
            pkgs+=(linux linux-headers) ;;
        linux-zen)
            pkgs+=(linux-zen linux-zen-headers) ;;
        linux-lts)
            pkgs+=(linux-lts linux-lts-headers) ;;
        linux-hardened)
            pkgs+=(linux-hardened linux-hardened-headers) ;;
        linux-libre)
            log_info "Enabling linux-libre repository..."
            if ! grep -q '^\[libre\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[libre]
SigLevel = Never
Server = https://repo.parabola.nu/libre/os/x86_64
EOF
            fi
            pacman -S --noconfirm --needed linux-libre linux-libre-headers
            log_warn "linux-libre removes non-free firmware/drivers. NVIDIA, Wi‑Fi, Bluetooth may stop working."
            ;;
        linux-cachyos-bore)
            log_info "Setting up CachyOS repository..."
            pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
            pacman-key --lsign-key F3B607488DB35A47
            local cachyos_keyring cachyos_mirrorlist
            cachyos_keyring=$(curl -sL 'https://mirror.cachyos.org/repo/x86_64/cachyos/' | grep -oP 'cachyos-keyring-\d+.*?\.pkg\.tar\.zst' | sort -V | tail -1)
            cachyos_mirrorlist=$(curl -sL 'https://mirror.cachyos.org/repo/x86_64/cachyos/' | grep -oP 'cachyos-mirrorlist-\d+.*?\.pkg\.tar\.zst' | sort -V | tail -1)
            [[ -z "${cachyos_keyring}" || -z "${cachyos_mirrorlist}" ]] && die 'Failed to locate CachyOS bootstrap packages'
            pacman -U --noconfirm "https://mirror.cachyos.org/repo/x86_64/cachyos/${cachyos_keyring}" "https://mirror.cachyos.org/repo/x86_64/cachyos/${cachyos_mirrorlist}"
            if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
            fi
            pacman -S --noconfirm --needed linux-cachyos-bore linux-cachyos-bore-headers
            ;;
        linux-bazzite-bin)
            log_info "Setting up Arch repositories for Bazzite kernel..."
            if ! pacman -Q artix-archlinux-support >/dev/null 2>&1; then
                pacman -S --noconfirm --needed artix-archlinux-support
            fi
            local arch_mirrorlist='/etc/pacman.d/mirrorlist-arch'
            if [[ ! -f "${arch_mirrorlist}" ]]; then
                install -Dm644 /dev/null "${arch_mirrorlist}"
                cat > "${arch_mirrorlist}" <<'MIRROR_EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR_EOF
            fi
            if ! grep -q '^\[extra\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
            fi
            if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
            fi
            pacman -S --noconfirm --needed linux-bazzite-bin linux-bazzite-bin-headers
            ;;
        xanmod)
            log_info "Setting up Chaotic-AUR for XanMod..."
            pacman-key --init
            pacman-key --populate artix
            pacman-key --recv-keys 3056513887B78AEB --keyserver hkp://keyserver.ubuntu.com
            pacman-key --lsign-key 3056513887B78AEB
            pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
            if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            fi
            pacman -S --noconfirm --needed "${KERNEL_PACKAGE}" "${KERNEL_HEADERS}"
            ;;
        tkg)
            log_info "Setting up TKG build dependencies..."
            pkgs+=(dkms bc cpio flex libelf pahole base-devel git)
            log_warn "TKG kernels must be manually compiled after installation. Repository will be cloned into /opt/linux-tkg."
            ;;
        *)
            die "unsupported kernel: ${kernel}" ;;
    esac

    case "${network_stack}" in
        dhcpcd+iwd)     pkgs+=(dhcpcd iwd "dhcpcd-${init}" "iwd-${init}") ;;
        networkmanager) pkgs+=(networkmanager "networkmanager-${init}") ;;
        connman)        pkgs+=(connman "connman-${init}") ;;
        none) ;;
    esac

    case "${fs_type}" in
        btrfs)     pkgs+=(btrfs-progs) ;;
        ext4)      pkgs+=(e2fsprogs) ;;
        xfs)       pkgs+=(xfsprogs) ;;
        f2fs)      pkgs+=(f2fs-tools) ;;
        bcachefs)  pkgs+=(bcachefs-tools) ;;
        exfat)     pkgs+=(exfatprogs) ;;
        zfs)
            log_info "Setting up OpenZFS repository..."
            if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf
[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
            fi
            pacman-key --recv-keys F75D9D76 --keyserver hkp://keyserver.ubuntu.com
            pacman-key --lsign-key F75D9D76
            pacman -S --noconfirm --needed dkms zfs-dkms zfs-utils zfs-initramfs
            log_warn "ZFS support is experimental. DKMS rebuilds may be required."
            ;;
        *) die "unsupported filesystem: ${fs_type}" ;;
    esac

    case "${bootloader}" in
        grub)    pkgs+=(grub os-prober) ;;
        refind)  pkgs+=(refind) ;;
        efistub) ;;
    esac

    printf '%s\n' "${pkgs[@]}" > "${PWD}/artix-pkgs.log"

    local debug_log="${PWD}/basestrap-debug.log"
    : > "${debug_log}"

    export GNUPGHOME="${GNUPGHOME:-/etc/pacman.d/gnupg}"
    mkdir -p "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"
    log_info "Initializing Artix keyring..."
    pacman-key --init
    pacman-key --populate artix

    if [[ "$(state_get ENABLE_ARCH_REPOS no)" == 'yes' ]]; then
        log_info "Installing Arch repository support..."
        pacman -S --noconfirm --needed artix-archlinux-support
        local arch_mirrorlist='/etc/pacman.d/mirrorlist-arch'
        if [[ ! -f "${arch_mirrorlist}" ]]; then
            install -Dm644 /dev/null "${arch_mirrorlist}"
            cat > "${arch_mirrorlist}" <<'MIRROR_EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
MIRROR_EOF
        fi

        if ! grep -q '^\[extra\]' /etc/pacman.conf; then
            cat <<'EOF' >> /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
        fi
        if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
            cat <<'EOF' >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
        fi
        log_info "Synchronizing package databases..."
        if ! pacman -Sy --noconfirm; then
            die "Failed to sync package databases — check mirrorlist configuration"
        fi
        log_info "Installing Arch Linux keyring..."
        pacman -S --noconfirm --needed archlinux-keyring
    fi

    log_info "Starting basestrap..."
    printf '%s\n' "${pkgs[@]}" >> "${debug_log}"
    if ! basestrap /mnt "${pkgs[@]}" \
        2>&1 | tee -a "${debug_log}" \
        | while IFS= read -r line; do
            log_info "${line}"
        done; then
        die "basestrap failed"
    fi
    [[ -x /mnt/bin/bash ]] || die "/mnt/bin/bash missing after basestrap"
    [[ -f /mnt/etc/os-release ]] || die "target root invalid after basestrap"
    log_info "Configuring locale..."
    artix-chroot /mnt /bin/bash -c "
        grep -q '^${locale} UTF-8' /etc/locale.gen || echo '${locale} UTF-8' >> /etc/locale.gen
        locale-gen
        cat > /etc/locale.conf <<EOF
LANG=${locale}
EOF
    "

    log_info "Configuring keymap..."
    cat <<EOF > /mnt/etc/vconsole.conf
KEYMAP=${keymap}
EOF

    log_info "Configuring timezone..."
    artix-chroot /mnt ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
    artix-chroot /mnt hwclock --systohc

    if [[ "${fs_type}" == 'zfs' ]]; then
        log_info "Generating hostid for ZFS..."
        artix-chroot /mnt zgenhostid

        log_info "Adding ZFS hook to mkinitcpio..."
        artix-chroot /mnt sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)/' /etc/mkinitcpio.conf
    fi

    if [[ "${kernel}" == 'tkg' ]]; then
        log_info "Cloning linux-tkg repository..."
        artix-chroot /mnt git clone https://github.com/Frogging-Family/linux-tkg /opt/linux-tkg || true
        log_info "TKG source ready in /opt/linux-tkg. Compile manually after reboot."
    fi

    if [[ "${fs_type}" != 'zfs' ]]; then
        log_info "Generating fstab..."
        fstabgen -U /mnt > /mnt/etc/fstab
    fi

    log_info "Base system installation complete."
}