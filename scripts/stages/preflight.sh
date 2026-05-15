#!/usr/bin/env bash
set -Eeuo pipefail;

stage_preflight() {
    if stage_should_skip preflight; then
        return 0;
    fi;

    require_root;
    require_efi;
    require_internet;

    local pacman_conf_backup='/tmp/pacman.conf.artixtui.bak'

    if [[ ! -f "${pacman_conf_backup}" ]]; then
        cp /etc/pacman.conf "${pacman_conf_backup}"
    fi

    if ! command_exists gum; then
        if [[ -f "/usr/local/bin/gum" ]]; then
            PATH="/usr/local/bin:${PATH}"   
        elif [[ -f "${BASE_DIR}/bin/gum" ]]; then
            log_info "Installing bundled gum binary...";
            install -Dm755 "${BASE_DIR}/bin/gum" /usr/local/bin/gum;
        else
            log_info "Gum not found. Building from source...";
            if ! command_exists go; then
                log_info "Installing Go...";
                pacman -S --noconfirm --needed go;
            fi
            local gum_tmp;
            gum_tmp="$(mktemp -d)";
            git clone --depth 1 https://github.com/charmbracelet/gum.git "${gum_tmp}";
            ( cd "${gum_tmp}"; go build -o gum .; install -Dm755 gum /usr/local/bin/gum; );
            rm -rf "${gum_tmp}";
            log_info "Gum compiled and installed to /usr/local/bin/gum.";
        fi
    fi

    local pkgs=();
    local fs_type;
    fs_type="$(state_get FS_TYPE ext4)";

    command_exists sgdisk       || pkgs+=(gptfdisk);
    command_exists partprobe    || pkgs+=(parted);
    command_exists cryptsetup   || pkgs+=(cryptsetup);
    command_exists mount        || pkgs+=(util-linux);
    command_exists mkfs.fat     || pkgs+=(dosfstools);
    command_exists lsblk        || pkgs+=(util-linux);
    command_exists wipefs       || pkgs+=(util-linux);
    command_exists btrfs        || pkgs+=(btrfs-progs);
    case "${fs_type}" in
        xfs)     command_exists mkfs.xfs || pkgs+=(xfsprogs) ;;
        f2fs)    command_exists mkfs.f2fs || pkgs+=(f2fs-tools) ;;
        exfat)   command_exists mkfs.exfat || pkgs+=(exfatprogs) ;;
        bcachefs) command_exists mkfs.bcachefs || pkgs+=(bcachefs-tools) ;;
        zfs)
            if ! command_exists zpool || ! modprobe zfs 2>/dev/null; then
                if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                    pacman-key --recv-keys F75D9D76 --keyserver hkp://keyserver.ubuntu.com
                    pacman-key --lsign-key F75D9D76
                    cat <<'EOF' >> /etc/pacman.conf

[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
                    pacman -Sy --noconfirm
                    pacman -Sl archzfs >/dev/null 2>&1 || die "archzfs repository unusable"
                fi

                local live_kernel
                live_kernel=$(uname -r)
                local zfs_pkg=""

                if pacman -Qq linux &>/dev/null; then
                    zfs_pkg="zfs-linux"
                elif pacman -Qq linux-lts &>/dev/null; then
                    zfs_pkg="zfs-linux-lts"
                elif pacman -Qq linux-zen &>/dev/null; then
                    zfs_pkg="zfs-linux-zen"
                elif pacman -Qq linux-hardened &>/dev/null; then
                    zfs_pkg="zfs-linux-hardened"
                else
                    # Fallback: attempt DKMS build for custom kernel
                    log_warn "No prebuilt ZFS package for running kernel (${live_kernel})"
                    log_warn "Attempting DKMS build – this may fail if headers are missing"
                    pkgs+=(zfs-dkms linux-headers-${live_kernel})
                fi

                if [[ -n "${zfs_pkg}" ]]; then
                    pkgs+=("${zfs_pkg}")
                fi
            fi
            ;;
    esac

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Installing required tools: ${pkgs[*]}";
        gum spin --spinner dot --title "Preflight – installing dependencies" -- \
            pacman -S --noconfirm --needed "${pkgs[@]}";
        log_info "Preflight dependencies installed.";
    fi;

    if pacman -Qq zfs-dkms &>/dev/null && ! modprobe zfs 2>/dev/null; then
        local kver
        kver=$(uname -r)
        log_info "Building ZFS DKMS module for kernel ${kver}..."

        if ! dkms autoinstall; then
            log_error "DKMS autoinstall failed."
            local make_log
            make_log=$(find /var/lib/dkms/zfs -name make.log 2>/dev/null | tail -n1)
            if [[ -n "${make_log}" && -f "${make_log}" ]]; then
                log_error "Last 20 lines of ${make_log}:"
                tail -n 20 "${make_log}" | while IFS= read -r line; do log_error "  ${line}"; done
            fi
            die "Failed to build ZFS module for custom kernel ${kver}. Use linux or linux-lts for reliable ZFS support."
        fi

        if ! modprobe zfs 2>/dev/null; then
            die "ZFS module still not loadable after DKMS build"
        fi
        log_info "ZFS module loaded successfully."
    fi

    if [[ "${fs_type}" == 'bcachefs' ]]; then
        local bcachefs_ver kernel_ver
        if command -v bcachefs >/dev/null; then
            bcachefs_ver=$(bcachefs version 2>/dev/null | grep -oP '\d+\.\d+' | head -1) || true
            if [[ -n "${bcachefs_ver}" ]]; then
                kernel_ver=$(uname -r | cut -d. -f1,2)
                if [[ "$(printf '%s\n' "${bcachefs_ver}" "${kernel_ver}" | sort -V | head -n1)" != "${bcachefs_ver}" ]]; then
                    log_warn "bcachefs-tools version ${bcachefs_ver} may be older than kernel ${kernel_ver}."
                    log_warn "Update the live ISO or bcachefs-tools to avoid superblock errors."
                fi
            fi
        fi
    fi
    
    stage_mark_done preflight;
}