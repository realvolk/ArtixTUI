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
    local target_kernel;
    local live_kernel_pkg="";
    fs_type="$(state_get FS_TYPE ext4)";
    target_kernel="$(state_get KERNEL_CHOICE linux)";

    command_exists sgdisk       || pkgs+=(gptfdisk);
    command_exists partprobe    || pkgs+=(parted);
    command_exists cryptsetup   || pkgs+=(cryptsetup);
    command_exists mount        || pkgs+=(util-linux);
    command_exists mkfs.fat     || pkgs+=(dosfstools);
    command_exists lsblk        || pkgs+=(util-linux);
    command_exists wipefs       || pkgs+=(util-linux);
    command_exists btrfs        || pkgs+=(btrfs-progs);

    case "$(uname -r)" in
        *lts*)       live_kernel_pkg="linux-lts" ;;
        *zen*)       live_kernel_pkg="linux-zen" ;;
        *hardened*)  live_kernel_pkg="linux-hardened" ;;
        *)           live_kernel_pkg="linux" ;;
    esac

    case "${fs_type}" in
        xfs)      command_exists mkfs.xfs || pkgs+=(xfsprogs) ;;
        f2fs)     command_exists mkfs.f2fs || pkgs+=(f2fs-tools) ;;
        exfat)    command_exists mkfs.exfat || pkgs+=(exfatprogs) ;;
        bcachefs) command_exists mkfs.bcachefs || pkgs+=(bcachefs-tools) ;;

        zfs)
            if [[ "${target_kernel}" != "linux" &&
                  "${target_kernel}" != "linux-lts" &&
                  "${target_kernel}" != "linux-zen" &&
                  "${target_kernel}" != "linux-hardened" ]]; then
                die "ZFS is only supported with linux, linux-lts, linux-zen, or linux-hardened kernels."
            fi

            if [[ "${target_kernel}" != "${live_kernel_pkg}" ]]; then
                die "Live ISO kernel (${live_kernel_pkg}) does not match target kernel (${target_kernel}) for ZFS installation."
            fi

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

            local zfs_pkg=""

            case "${target_kernel}" in
                linux)           zfs_pkg="zfs-linux" ;;
                linux-lts)       zfs_pkg="zfs-linux-lts" ;;
                linux-zen)       zfs_pkg="zfs-linux-zen" ;;
                linux-hardened)  zfs_pkg="zfs-linux-hardened" ;;
            esac

            if [[ -n "${zfs_pkg}" ]]; then
                pkgs+=("${zfs_pkg}")
            fi

            ;;
    esac

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Installing required tools: ${pkgs[*]}";
        gum spin --spinner dot --title "Preflight – installing dependencies" -- \
            pacman -S --noconfirm --needed "${pkgs[@]}";
        log_info "Preflight dependencies installed.";
    fi;

    if [[ "${fs_type}" == 'zfs' ]]; then
        log_info "Kernel: $(uname -r)"
        log_info "Installed ZFS packages:"
        pacman -Q | grep '^zfs' || true
        log_info "Available ZFS modules:"
        find /usr/lib/modules -iname 'zfs.ko*' 2>/dev/null || true
        depmod -a

        if ! modprobe zfs 2>/dev/null; then
            local expected_kver
            expected_kver=$(pacman -Qi "${zfs_pkg}" 2>/dev/null | grep -oP 'for kernel \K[\d.]+' || true)

            if [[ -n "${expected_kver}" ]]; then
                log_error "Prebuilt ZFS module (${zfs_pkg}) is for kernel ${expected_kver}, but running kernel is $(uname -r)."
                die "Kernel version mismatch. The archzfs repo has not yet built ZFS for this kernel. Wait for an update or use a different live ISO."
            fi

            die "Failed to load ZFS kernel module."
        fi

        log_info "ZFS kernel module loaded successfully."
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