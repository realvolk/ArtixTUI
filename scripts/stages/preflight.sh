#!/usr/bin/env bash
set -Eeuo pipefail;

stage_preflight() {
    if stage_should_skip preflight; then
        return 0;
    fi;

    require_root;
    require_efi;
    require_internet;

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

            git clone --depth 1 \
                https://github.com/charmbracelet/gum.git \
                "${gum_tmp}";

            (
                cd "${gum_tmp}";
                go build -o gum .;
                install -Dm755 gum /usr/local/bin/gum;
            );

            rm -rf "${gum_tmp}";

            log_info "Gum compiled and installed to /usr/local/bin/gum.";
        fi
    fi

    local pkgs=();
    local fs_type;
    fs_type="$(state_get FS_TYPE ext4)";

    command_exists sgdisk       || pkgs+=(gptfdisk);
    command_exists cryptsetup   || pkgs+=(cryptsetup);
    command_exists mkfs.fat     || pkgs+=(dosfstools);
    command_exists lsblk        || pkgs+=(util-linux);
    command_exists wipefs       || pkgs+=(util-linux);
    command_exists btrfs        || pkgs+=(btrfs-progs);

    case "${fs_type}" in
        xfs)
            command_exists mkfs.xfs \
                || pkgs+=(xfsprogs);
            ;;
        f2fs)
            command_exists mkfs.f2fs \
                || pkgs+=(f2fs-tools);
            ;;
        exfat)
            command_exists mkfs.exfat \
                || pkgs+=(exfatprogs);
            ;;
        bcachefs)
            command_exists mkfs.bcachefs \
                || pkgs+=(bcachefs-tools);
            ;;
        zfs)
            if ! command_exists zpool || ! modprobe zfs 2>/dev/null; then                if ! grep -q '^\[archzfs\]' /etc/pacman.conf; then
                    cat <<'EOF' >> /etc/pacman.conf

[archzfs]
Server = https://archzfs.com/$repo/x86_64
EOF
                    pacman -Sy --noconfirm
                fi

                pkgs+=(zfs-utils dkms zfs-dkms)
                local kver hdr_pkg
                kver=$(uname -r)
                if [[ "${kver}" == *-lts* ]]; then
                    hdr_pkg='linux-lts-headers'
                elif [[ "${kver}" == *-zen* ]]; then
                    hdr_pkg='linux-zen-headers'
                elif [[ "${kver}" == *-hardened* ]]; then
                    hdr_pkg='linux-hardened-headers'
                else
                    hdr_pkg='linux-headers'
                fi
                if pacman -Si "${hdr_pkg}" &>/dev/null; then
                    pkgs+=("${hdr_pkg}")
                else
                    hdr_pkg=$(pacman -Qsq 'linux[0-9]*-headers' 2>/dev/null | head -n1)
                    if [[ -n "${hdr_pkg}" ]]; then
                        pkgs+=("${hdr_pkg}")
                    else
                        die "Cannot determine kernel headers package for ${kver}"
                    fi
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
    
    if [[ "${fs_type}" == 'zfs' ]]; then
        if ! modprobe zfs 2>/dev/null; then
            log_info "Building ZFS module for kernel ${kver}..."
            dkms autoinstall 2>/dev/null || true
            sleep 2
            modprobe zfs 2>/dev/null || {
                log_error "ZFS kernel module still unavailable after DKMS build."
                log_error "Your kernel ($(uname -r)) may be too new for the available zfs-dkms."
                log_error "Options:"
                log_error "  1. Use a different filesystem (ext4, btrfs, xfs)"
                log_error "  2. Use the 'linux' or 'linux-lts' kernel on the live ISO"
                log_error "  3. Wait for upstream ZFS to support kernel ${kver}"
                return 1
            }
        fi
        log_info "ZFS kernel module loaded successfully."
    fi

    stage_mark_done preflight;
}