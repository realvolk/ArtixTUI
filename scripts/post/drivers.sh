#!/usr/bin/env bash
set -Eeuo pipefail

[[ -f /etc/artix-installer.conf ]] && source /etc/artix-installer.conf
if [[ -f ./scripts/install/services.sh ]]; then
    source ./scripts/install/services.sh
elif [[ -f /usr/local/lib/artix-installer/services.sh ]]; then
    source /usr/local/lib/artix-installer/services.sh
fi

get_gpu_vendor() {
    local vendors
    vendors=$(lspci -nn 2>/dev/null | awk '/VGA|3D/' | grep -oiE 'nvidia|intel|amd')
    if   grep -qi nvidia <<<"${vendors}"; then printf 'nvidia\n'
    elif grep -qi amd    <<<"${vendors}"; then printf 'amd\n'
    elif grep -qi intel  <<<"${vendors}"; then printf 'intel\n'
    else printf 'unknown\n'
    fi
}

get_gpu_info() {
    lspci -nn 2>/dev/null | awk -F': ' '/VGA|3D/ {print $3}' | xargs || true
}

get_pci_id() {
    lspci -n 2>/dev/null | awk '/0300|0302/ {print $3}' | awk -F':' '{print $2}' | head -n1 || true
}

detect_vm() {
    local vm
    vm=$(grep -h -oE 'vmware|qemu|kvm|oracle|virtualbox' /sys/class/dmi/id/product_name /sys/class/dmi/id/sys_vendor 2>/dev/null | head -n1)
    [[ -n "${vm}" ]] && printf '%s\n' "${vm}" || printf 'none\n'
}

export -f get_gpu_vendor get_gpu_info get_pci_id detect_vm

install_drivers() {
    local pkgs=() rc=0 initramfs_tool='mkinitcpio'
    local gpu_vendor gpu_info pci_id vm_type x_stack wm_de kernel_choice
    gpu_vendor=$(get_gpu_vendor | tr -d '[:space:]')
    gpu_vendor="${gpu_vendor:-unknown}"
    gpu_info=$(get_gpu_info)
    gpu_info="${gpu_info:-Unknown}"
    pci_id=$(get_pci_id)
    vm_type=$(detect_vm)
    x_stack="$(state_get X_STACK xorg | tr -d '[:space:]')"
    wm_de="$(state_get WM_DE none | tr -d '[:space:]')"
    kernel_choice="$(state_get KERNEL_CHOICE linux | tr -d '[:space:]')"

    mkdir -p /root/ArtixTUI
    : > /root/ArtixTUI/drivers-debug.log

    case "${kernel_choice}" in
        linux)                   pkgs+=(linux-headers) ;;
        linux-lts)               pkgs+=(linux-lts-headers) ;;
        linux-hardened)          pkgs+=(linux-hardened-headers) ;;
        linux-zen)               pkgs+=(linux-zen-headers) ;;
        linux-cachy|linux-cachyos)
            pacman -Si linux-cachyos-headers >/dev/null 2>&1 && pkgs+=(linux-cachyos-headers) \
                || pacman -Si linux-cachy-headers >/dev/null 2>&1 && pkgs+=(linux-cachy-headers) ;;
        linux-bazzite-bin|bazzite) initramfs_tool='dracut' ;;
        xanmod)
            local cpu_level kernel_headers
            cpu_level=$(/lib/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -oE 'x86-64-v[2-4]' | head -n1)
            case "${cpu_level}" in
                x86-64-v4) kernel_headers='linux-xanmod-x64v4-headers' ;;
                x86-64-v3) kernel_headers='linux-xanmod-x64v3-headers' ;;
                x86-64-v2) kernel_headers='linux-xanmod-x64v2-headers' ;;
                *)         kernel_headers='linux-xanmod-headers' ;;
            esac
            pkgs+=("${kernel_headers}") ;;
        tkg) ;;
    esac

    {
        log_info "GPU detected: ${gpu_info}"
        log_info "Virtualization: ${vm_type}"
        log_info "Display stack: ${x_stack}"
        log_info "Kernel: ${kernel_choice}"

        if [[ "${vm_type}" != 'none' ]]; then
            log_info "VM detected. Installing guest drivers..."
            case "${vm_type}" in
                kvm|qemu)
                    pkgs+=(spice-vdagent qemu-guest-agent)
                    if [[ "${x_stack}" == 'xlibre' ]]; then
                        pkgs+=(xlibre-video-qxl)
                    else
                        pkgs+=(xf86-video-qxl)
                    fi
                    ;;
                vmware)
                    pkgs+=(open-vm-tools)
                    if [[ "${x_stack}" == 'xlibre' ]]; then
                        pkgs+=(xlibre-video-vmware)
                    else
                        pkgs+=(xf86-video-vmware)
                    fi
                    ;;
                oracle|virtualbox)
                    pkgs+=(virtualbox-guest-utils)
                    ;;
            esac
        fi

        if [[ "${gpu_vendor}" == 'nvidia' && -n "${pci_id}" ]]; then
            if (( 16#${pci_id} >= 16#1e00 )); then
                log_info "Newer NVIDIA → nvidia-open-dkms"
                pkgs+=(nvidia-open-dkms nvidia-utils mesa)
            else
                log_info "Older NVIDIA → proprietary"
                pkgs+=(nvidia-dkms nvidia-utils nvidia-settings mesa)
            fi
        elif [[ "${gpu_vendor}" == 'intel' ]]; then
            log_info "Intel GPU detected."
            if [[ "${x_stack}" == 'xlibre' ]]; then
                pkgs+=(xlibre-video-intel mesa vulkan-intel)
            else
                pkgs+=(xf86-video-intel intel-media-driver mesa vulkan-intel)
            fi
        elif [[ "${gpu_vendor}" == 'amd' ]]; then
            log_info "AMD GPU detected."
            if [[ "${x_stack}" == 'xlibre' ]]; then
                pkgs+=(xlibre-video-amdgpu mesa vulkan-radeon)
            else
                pkgs+=(xf86-video-amdgpu mesa vulkan-radeon)
            fi
        else
            log_info "Unknown GPU → VESA fallback"
            if [[ "${x_stack}" == 'xlibre' ]]; then
                pkgs+=(mesa)
            else
                pkgs+=(mesa xf86-video-vesa)
            fi
        fi

        [[ "${x_stack}" == 'xlibre' ]] && pkgs+=(xlibre-xserver) || pkgs+=(xorg-server)

        case "${wm_de}" in hyprland|niri|sway) pkgs+=(xorg-xwayland) ;; esac

        log_info "Final package list:"
        printf ' - %s\n' "${pkgs[@]}"

        log_info "Installing: ${pkgs[*]}"
        export COLUMNS=80 LINES=24 TERM=dumb

        if pacman --color=never --noconfirm --needed -S "${pkgs[@]}"; then
            rc=0
        else
            rc=$?
            log_error "Driver installation failed (rc=${rc})"
        fi

        if [[ ${rc} -eq 0 && "${gpu_vendor}" == 'nvidia' ]]; then
            log_info "Regenerating initramfs after NVIDIA..."
            if [[ "${initramfs_tool}" == 'dracut' ]]; then
                dracut --regenerate-all --force || rc=$?
            else
                mkinitcpio -P || rc=$?
            fi
        fi

        [[ "${vm_type}" == 'kvm' || "${vm_type}" == 'qemu' ]] && enable_service qemu-guest-agent

        if [[ ${rc} -eq 0 ]]; then
            log_info "Driver installation complete."
        else
            log_error "Driver installation failed."
        fi
    } >> /root/ArtixTUI/drivers-debug.log 2>&1

    if [[ ${rc} -ne 0 && "${gpu_vendor}" == 'nvidia' ]]; then
        log_error "NVIDIA failed. Trying nouveau fallback..."
        {
            export COLUMNS=80 LINES=24 TERM=dumb
            if [[ "${x_stack}" == 'xlibre' ]]; then
                pacman --color=never --noconfirm --needed -S xlibre-video-nouveau mesa
            else
                pacman --color=never --noconfirm --needed -S xf86-video-nouveau mesa
            fi
            rc=$?
        } >> /root/ArtixTUI/drivers-debug.log 2>&1
    fi

    return "${rc}"
}