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
    command_exists cryptsetup   || pkgs+=(cryptsetup);
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
                fi
                pkgs+=(zfs-utils dkms zfs-dkms)
                local kver hdr_pkg
                kver=$(uname -r)
                if [[ "${kver}" == *-lts* ]]; then hdr_pkg='linux-lts-headers'
                elif [[ "${kver}" == *-zen* ]]; then hdr_pkg='linux-zen-headers'
                elif [[ "${kver}" == *-hardened* ]]; then hdr_pkg='linux-hardened-headers'
                else hdr_pkg='linux-headers'; fi
                if pacman -Si "${hdr_pkg}" &>/dev/null; then pkgs+=("${hdr_pkg}")
                else
                    hdr_pkg=$(pacman -Qsq 'linux[0-9]*-headers' 2>/dev/null | head -n1)
                    [[ -n "${hdr_pkg}" ]] && pkgs+=("${hdr_pkg}") || die "Cannot determine kernel headers for ${kver}"
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
        local kver dkms_log
        kver=$(uname -r)
        local kver_major kver_minor
        kver_major=$(echo "${kver}" | grep -oP '^\d+')
        kver_minor=$(echo "${kver}" | grep -oP '^\d+\.\K\d+')
        if [[ "${kver_major}" -gt 6 || ( "${kver_major}" -eq 6 && "${kver_minor}" -gt 12 ) ]]; then
            log_warn "Kernel ${kver} may be too new for ZFS (supports up to 6.12)."
        fi

        if ! modprobe zfs 2>/dev/null; then
            log_info "Building ZFS module for kernel ${kver}..."
            dkms_log=$(dkms autoinstall 2>&1) || true
            log_info "DKMS output: ${dkms_log}"

            local waited=0
            while dkms status 2>/dev/null | grep -q 'zfs.*: added'; do
                sleep 2
                waited=$((waited + 2))
                if [[ ${waited} -ge 120 ]]; then
                    log_error "DKMS build timed out after 120 seconds."
                    break
                fi
            done

            if modprobe zfs 2>/dev/null; then
                log_info "ZFS kernel module loaded successfully."
            else
                log_error "ZFS kernel module still unavailable after DKMS build."
                log_error "DKMS status:"
                dkms status 2>&1 | while IFS= read -r line; do log_error "  ${line}"; done
                local make_log
                make_log=$(find /var/lib/dkms/zfs -name make.log 2>/dev/null | tail -n1)
                if [[ -n "${make_log}" && -f "${make_log}" ]]; then
                    log_error "Last 20 lines of ${make_log}:"
                    tail -n 20 "${make_log}" | while IFS= read -r line; do log_error "  ${line}"; done
                fi
                log_error "Your kernel (${kver}) is too new for the available zfs-dkms."
                log_error "Use a live ISO with an LTS kernel for ZFS support."
                return 1
            fi
        else
            log_info "ZFS kernel module already loaded."
        fi
    fi

    stage_mark_done preflight;
}