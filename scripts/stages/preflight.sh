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
                local kver running_kernel_pkg headers_pkg
                kver=$(uname -r)

                running_kernel_pkg=$(pacman -Qqo /lib/modules 2>/dev/null || true)
                if [[ -z "${running_kernel_pkg}" ]]; then
                    for candidate in linux linux-lts linux-zen linux-hardened; do
                        if pacman -Qq "${candidate}" &>/dev/null; then
                            running_kernel_pkg="${candidate}"
                            break
                        fi
                    done
                fi

                if [[ -n "${running_kernel_pkg}" ]]; then
                    headers_pkg="${running_kernel_pkg}-headers"
                    if pacman -Si "${headers_pkg}" &>/dev/null; then
                        pkgs+=("${headers_pkg}")
                    else
                        die "Kernel headers package '${headers_pkg}' not found for running kernel '${running_kernel_pkg}'"
                    fi
                else
                    if pacman -Si "linux-headers-${kver}" &>/dev/null; then
                        pkgs+=("linux-headers-${kver}")
                    else
                        die "Cannot find kernel headers for ${kver}. ZFS requires matching kernel headers."
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
        local kver
        kver=$(uname -r)
        if ! modprobe zfs 2>/dev/null; then
            log_info "Building ZFS module for kernel ${kver}..."
            local dkms_output dkms_rc
            dkms_output=$(dkms autoinstall 2>&1) || true
            dkms_rc=$?
            log_info "DKMS output: ${dkms_output}"

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
                log_error "Your kernel (${kver}) may be incompatible with the available zfs-dkms."
                log_error "Consider using a live ISO with a standard kernel (linux or linux-lts)."
                return 1
            fi
        else
            log_info "ZFS kernel module already loaded."
        fi
    fi

    stage_mark_done preflight;
}