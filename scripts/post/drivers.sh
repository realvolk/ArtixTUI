#!/usr/bin/env bash
set -Eeuo pipefail;

[[ -f /etc/artix-installer.conf ]] \
    && source /etc/artix-installer.conf

if [[ -f ./scripts/install/services.sh ]]; then
    source ./scripts/install/services.sh
elif [[ -f /usr/local/lib/artix-installer/services.sh ]]; then
    source /usr/local/lib/artix-installer/services.sh
fi

get_gpu_vendor() {
    local gpu_vendor;

    gpu_vendor=$(
        lspci -nn 2>/dev/null \
            | awk -F' ' '/VGA|3D/ {print tolower($0)}' \
            | grep -oE 'nvidia|intel|amd' \
            | head -n1 \
            || true
    );

    printf '%s\n' "${gpu_vendor}";
}

get_gpu_info() {
    lspci -nn 2>/dev/null \
        | awk -F': ' '/VGA|3D/ {print $3}' \
        | xargs \
        || true;
}

get_pci_id() {
    lspci -n 2>/dev/null \
        | awk '/0300|0302/ {print $3}' \
        | awk -F':' '{print $2}' \
        | head -n1 \
        || true;
}

detect_vm() {
    local vm="none";

    if grep -qaE \
        'virt|vmware|kvm|qemu|oracle|virtualbox' \
        /sys/class/dmi/id/product_name \
        /sys/class/dmi/id/sys_vendor \
        2>/dev/null; then

        vm=$(
            grep -oE \
                'vmware|qemu|kvm|oracle|virtualbox' \
                /sys/class/dmi/id/product_name \
                2>/dev/null \
                | head -n1
        );

        [[ -z "${vm}" ]] && vm="kvm";
    fi;

    printf '%s\n' "${vm}";
}

export -f \
    get_gpu_vendor \
    get_gpu_info \
    get_pci_id \
    detect_vm

install_drivers() {
    local pkgs=();
    local gpu_vendor;
    local gpu_info;
    local pci_id;
    local vm_type;
    local x_stack;
    local wm_de;
    local kernel_choice;
    local rc=0;

    gpu_vendor="$(get_gpu_vendor)";
    gpu_info="$(get_gpu_info)";
    pci_id="$(get_pci_id)";
    vm_type="$(detect_vm)";
    x_stack="$(state_get X_STACK xorg)";
    wm_de="$(state_get WM_DE none)";
    kernel_choice="$(state_get KERNEL_CHOICE linux)";

    mkdir -p /root/ArtixTUI

    : > /root/ArtixTUI/drivers-debug.log

    case "${kernel_choice}" in
        linux)
            pkgs+=(linux-headers)
            ;;

        linux-lts)
            pkgs+=(linux-lts-headers)
            ;;

        linux-hardened)
            pkgs+=(linux-hardened-headers)
            ;;

        linux-zen)
            pkgs+=(linux-zen-headers)
            ;;

        xanmod)
            pkgs+=(linux-xanmod-headers)
            ;;

        tkg)
            ;;
    esac

    {
        printf '[*] GPU detected: %s\n' "${gpu_info:-Unknown}"
        printf '[*] Virtualization detected: %s\n' "${vm_type}"
        printf '[*] Selected display stack: %s\n\n' "${x_stack}"

        if [[ "${vm_type}" != 'none' ]]; then
            printf '[*] Virtual machine detected. Installing guest drivers...\n\n'

            case "${vm_type}" in
                kvm|qemu)
                    pkgs+=(
                        spice-vdagent
                        qemu-guest-agent
                        xf86-video-qxl
                    )
                    ;;

                vmware)
                    pkgs+=(
                        xf86-video-vmware
                        open-vm-tools
                    )
                    ;;

                oracle|virtualbox)
                    pkgs+=(
                        virtualbox-guest-utils
                    )
                    ;;
            esac
        fi

        if [[ "${gpu_vendor}" == 'nvidia' && -n "${pci_id}" ]]; then
            local pci_hex

            pci_hex=$((16#${pci_id}))

            if (( pci_hex >= 16#1e00 )); then
                printf '[*] Newer NVIDIA GPU detected. Using nvidia-open-dkms...\n\n'

                pkgs+=(
                    nvidia-open-dkms
                    nvidia-utils
                    mesa
                )
            else
                printf '[*] Older NVIDIA GPU detected. Using proprietary NVIDIA stack...\n\n'

                pkgs+=(
                    nvidia-dkms
                    nvidia-utils
                    nvidia-settings
                    mesa
                )
            fi

        elif [[ "${gpu_vendor}" == 'intel' ]]; then
            printf '[*] Intel GPU detected. Installing Intel graphics stack...\n\n'

            if [[ "${x_stack}" == 'xlibre' ]]; then
                pkgs+=(
                    xlibre-video-intel
                    mesa
                    vulkan-intel
                )
            else
                pkgs+=(
                    xf86-video-intel
                    intel-media-driver
                    mesa
                    vulkan-intel
                )
            fi

        elif [[ "${gpu_vendor}" == 'amd' ]]; then
            printf '[*] AMD GPU detected. Installing AMD graphics stack...\n\n'

            if [[ "${x_stack}" == 'xlibre' ]]; then
                pkgs+=(
                    xlibre-video-amdgpu
                    mesa
                    vulkan-radeon
                )
            else
                pkgs+=(
                    xf86-video-amdgpu
                    mesa
                    vulkan-radeon
                )
            fi

        else
            printf '[*] Unknown GPU detected. Falling back to VESA...\n\n'

            if [[ "${x_stack}" == 'xlibre' ]]; then
                pkgs+=(
                    mesa
                )
            else
                pkgs+=(
                    mesa
                    xf86-video-vesa
                )
            fi
        fi

        if [[ "${x_stack}" == 'xlibre' ]]; then
            pkgs+=(xlibre-xserver)
        else
            pkgs+=(xorg-server)
        fi

        case "${wm_de}" in
            hyprland|niri|sway)
                pkgs+=(xorg-xwayland)
                ;;
        esac

        printf '[*] Selected packages:\n'
        printf ' - %s\n' "${pkgs[@]}"

        printf '\n[*] Starting package installation...\n\n'

        export COLUMNS=80
        export LINES=24
        export TERM=dumb

        pacman \
            --color=never \
            --noconfirm \
            --needed \
            -S \
            "${pkgs[@]}"

        rc=$?

        if [[ "${vm_type}" == 'kvm' || "${vm_type}" == 'qemu' ]]; then
            enable_service qemu-guest-agent
        fi

        printf '\n[*] Driver installation complete.\n'

    } >> /root/ArtixTUI/drivers-debug.log 2>&1

    if [[ ${rc} -ne 0 ]]; then
        if [[ "${gpu_vendor}" == 'nvidia' ]]; then
            {
                printf '[!] NVIDIA driver install failed.\n'
                printf '[*] Attempting nouveau fallback...\n\n'

                export COLUMNS=80
                export LINES=24
                export TERM=dumb

                if [[ "${x_stack}" == 'xlibre' ]]; then
                    pacman \
                        --color=never \
                        --noconfirm \
                        --needed \
                        -S \
                        xlibre-video-nouveau \
                        mesa
                else
                    pacman \
                        --color=never \
                        --noconfirm \
                        --needed \
                        -S \
                        xf86-video-nouveau \
                        mesa
                fi

                rc=$?
            } >> /root/ArtixTUI/drivers-debug.log 2>&1
        fi

        return "${rc}"
    fi
}