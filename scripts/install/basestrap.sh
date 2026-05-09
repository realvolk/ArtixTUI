#!/usr/bin/env bash
set -Eeuo pipefail;

install_base_system() {
    local init;
    local kernel;
    local fs_type;
    local bootloader;
    local network_stack;
    local user_shell;

    init="$(state_get INIT)";
    kernel="$(state_get KERNEL_CHOICE linux)";
    fs_type="$(state_get FS_TYPE ext4)";
    bootloader="$(state_get BOOTLOADER grub)";
    network_stack="$(state_get NETWORK_STACK dhcpcd+iwd)";
    user_shell="$(state_get USER_SHELL bash)";

    local ucode='amd-ucode';

    grep -q 'GenuineIntel' /proc/cpuinfo \
        && ucode='intel-ucode';

    local pkgs=(
        base
        base-devel
        linux-firmware

        bash
        nano
        vim
        sudo

        git
        curl
        wget
        pciutils
        dialog

        "${ucode}"
        "${init}"

        "elogind-${init}"
        dbus

        efibootmgr
    );

    case "${user_shell}" in
        bash)
            ;;
        
        zsh)
            pkgs+=(zsh);
            ;;

        fish)
            pkgs+=(fish);
            ;;

        *)
            die "unsupported shell: ${user_shell}";
            ;;
    esac;

    case "${kernel}" in
        linux)
            pkgs+=(
                linux
                linux-headers
            );
            ;;

        linux-lts)
            pkgs+=(
                linux-lts
                linux-lts-headers
            );
            ;;

        linux-hardened)
            pkgs+=(
                linux-hardened
                linux-hardened-headers
            );
            ;;

        linux-libre)
            printf '[*] Enabling linux-libre repository...\n';

            if ! grep -q '^\[libre\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[libre]
SigLevel = Never
Server = https://repo.parabola.nu/libre/os/x86_64
EOF
            fi

            pacman -Sy --noconfirm;

            pkgs+=(
                linux-libre
                linux-libre-headers
            );

            printf '\n[!] WARNING: linux-libre removes support for non-free firmware and drivers.\n';
            printf '[!] NVIDIA GPUs, Wi-Fi, Bluetooth, and other hardware may stop working.\n\n';
            ;;

        linux-cachyos-bore)
            printf '[*] Setting up CachyOS repository...\n';

            pacman-key \
                --recv-keys F3B607488DB35A47 \
                --keyserver keyserver.ubuntu.com;

            pacman-key \
                --lsign-key F3B607488DB35A47;

            pacman -U --noconfirm \
                'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
                'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst';

            if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
            fi

            pacman -Sy --noconfirm;

            pkgs+=(
                linux-cachyos-bore
                linux-cachyos-bore-headers
            );
            ;;

        linux-bazzite-bin)
            if ! pacman -Q artix-archlinux-support >/dev/null 2>&1; then
                printf '[*] Installing Arch repository support...\n';

                pacman -Sy --noconfirm --needed \
                    artix-archlinux-support;
            fi

            if ! grep -q '^\[extra\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
            fi

            pacman -Sy --noconfirm;

            pkgs+=(
                linux-bazzite-bin
            );
            ;;

        xanmod)
            local cpu_level;
            local kernel_pkg;

            cpu_level=$(
                /lib/ld-linux-x86-64.so.2 --help \
                    | grep -E 'x86-64-v[2-4] \(supported' \
                    | head -n1 \
                    | awk '{print $1}'
            );

            case "${cpu_level}" in
                x86-64-v4)
                    kernel_pkg='linux-xanmod-x64v4';
                    ;;

                x86-64-v3)
                    kernel_pkg='linux-xanmod-x64v3';
                    ;;

                x86-64-v2)
                    kernel_pkg='linux-xanmod-x64v2';
                    ;;

                *)
                    kernel_pkg='linux-xanmod';
                    ;;
            esac;

            printf '[*] Setting up Chaotic-AUR for XanMod...\n';

            pacman-key --init;
            pacman-key --populate artix;

            pacman-key \
                --recv-keys FBA220DFC880C036 \
                --keyserver hkp://keyserver.ubuntu.com;

            pacman-key \
                --lsign-key FBA220DFC880C036;

            pacman -U --noconfirm \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst';

            if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            fi

            pacman -Sy --noconfirm;

            pkgs+=(
                "${kernel_pkg}"
                "${kernel_pkg}-headers"
            );
            ;;

        tkg)
            printf '[*] Setting up TKG build dependencies...\n';

            pkgs+=(
                dkms
                bc
                cpio
                flex
                libelf
                pahole
                base-devel
                git
            );

            printf '\n[!] TKG kernels must be manually compiled after installation.\n';
            printf '[!] Repository will be cloned into /opt/linux-tkg.\n\n';
            ;;

        *)
            die "unsupported kernel: ${kernel}";
            ;;
    esac;

    case "${network_stack}" in
        dhcpcd+iwd)
            pkgs+=(
                dhcpcd
                iwd
                "dhcpcd-${init}"
                "iwd-${init}"
            );
            ;;

        networkmanager)
            pkgs+=(
                networkmanager
                "networkmanager-${init}"
            );
            ;;

        connman)
            pkgs+=(
                connman
                "connman-${init}"
            );
            ;;

        none)
            ;;
    esac;

    case "${fs_type}" in
        btrfs)
            pkgs+=(btrfs-progs);
            ;;

        ext4)
            pkgs+=(e2fsprogs);
            ;;

        xfs)
            pkgs+=(xfsprogs);
            ;;

        f2fs)
            pkgs+=(f2fs-tools);
            ;;

        bcachefs)
            pkgs+=(bcachefs-tools);
            ;;

        exfat)
            pkgs+=(
                exfatprogs
                dosfstools
            );
            ;;

        zfs)
            printf '[*] Setting up OpenZFS repository...\n';

            if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
            fi

            pacman-key \
                --recv-keys F75D9D76 \
                --keyserver hkp://keyserver.ubuntu.com;

            pacman-key \
                --lsign-key F75D9D76;

            pacman -Sy --noconfirm;

            pkgs+=(
                dkms
                zfs-dkms
                zfs-utils
            );

            printf '\n[!] WARNING: ZFS support is experimental.\n';
            printf '[!] DKMS rebuilds may be required after kernel updates.\n\n';
            ;;

[extra]
Include = /etc/pacman.d/mirrorlist-arch
EOF
            fi

            pacman -Sy --noconfirm;

            pkgs+=(
                zfs-utils
                zfs-dkms
            );

            printf '\n[!] WARNING: ZFS support on Arch/Artix is experimental.\n';
            printf '[!] Kernel updates may occasionally break ZFS modules.\n\n';
            ;;

        *)
            die "unsupported filesystem: ${fs_type}";
            ;;
    esac;

    case "${bootloader}" in
        grub)
            pkgs+=(
                grub
                os-prober
            );
            ;;

        refind)
            pkgs+=(refind);
            ;;

        efistub)
            ;;
    esac;

    printf '%s\n' "${pkgs[@]}" \
        > "${PWD}/artix-pkgs.log";

    {
        printf '[*] Initializing Artix keyring...\n';

        pacman-key --init;
        pacman-key --populate artix;

        if [[ "$(state_get ENABLE_ARCH_REPOS no)" == 'yes' ]]; then
            printf '[*] Installing Arch repository support...\n';

            pacman -Sy --noconfirm --needed \
                artix-archlinux-support;

            printf '[*] Enabling Arch repositories...\n';

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

            printf '[*] Synchronizing package databases...\n';

            pacman -Sy;

            printf '[*] Installing Arch Linux keyring...\n';

            pacman -S --noconfirm --needed \
                archlinux-keyring;
        fi

        printf '[*] Starting basestrap...\n';

        local debug_log;

        debug_log="${PWD}/basestrap-debug.log";

        printf '\n[*] Installing packages:\n' \
            | tee "${debug_log}";

        printf '%s\n' "${pkgs[@]}" \
            | tee -a "${debug_log}";

        basestrap /mnt "${pkgs[@]}" \
            2>&1 | tee -a "${debug_log}";

        if [[ "${kernel}" == 'tkg' ]]; then
            printf '[*] Cloning linux-tkg repository...\n';

            artix-chroot /mnt git clone \
                https://github.com/frogging-family/linux-tkg \
                /opt/linux-tkg \
                || true;

            printf '\n[*] TKG source ready in /opt/linux-tkg\n';
            printf '[*] Compile manually after reboot with:\n';
            printf '    cd /opt/linux-tkg && ./install.sh\n\n';
        fi
        
        printf '[*] Generating fstab...\n';

        fstabgen -U /mnt >> /mnt/etc/fstab;

        printf '\n[*] Base system installation complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " Base Installation " \
        --programbox 22 90;
}