#!/usr/bin/env bash
set -o pipefail;

LOG_FILE="/var/log/artix-postinstall.log"
exec 3>&1
exec 4>&2
trap 'stty sane; clear' EXIT

function _report_err {
    local exit_code="${1}";
    local task="${2}";
    dialog --clear --title " Error (Code: ${exit_code}) " --msgbox "Task ${task} failed.\n\nCheck ${LOG_FILE} for details." 8 50 2>&1 >/dev/tty;
    exit "${exit_code}";
}

[[ -f /var/lib/artix-firstboot-done ]] && exit 0;
[[ -f /etc/install_config.conf ]] && source /etc/install_config.conf;

INIT="openrc";
[[ -d /run/runit ]] && INIT="runit";
[[ -d /run/dinit ]] && INIT="dinit";
[[ -d /run/s6    ]] && INIT="s6";

DRV_CHOICE=1;

_tui_msg() { stty sane; dialog --clear --title "${1}" --msgbox "${2}" 12 60 2>&1 >/dev/tty; }
_tui_yesno() { stty sane; dialog --clear --title "${1}" --yesno "${2}" 8 50 2>&1 >/dev/tty; }
_tui_menu() { stty sane; dialog --clear --stdout --title "${1}" --menu "${2}" 15 55 5 "${@:3}" 2>&1 >/dev/tty; }

function _error_exit {
    local reason="${1}";
    dialog --clear --title "Error" --msgbox "${reason^}" 8 50 2>&1 >/dev/tty;
    exit 1;
}

function _enable_arch_repos {
    if _tui_yesno "Arch Repos" "Would you like to enable official Arch Linux repositories (Extra, Multilib)?"; then
        {
            sed -i '/\[extra\]/,/Include = \/etc\/pacman.d\/mirrorlist-arch/d' /etc/pacman.conf 2>/dev/null;
            sed -i '/\[multilib\]/,/Include = \/etc\/pacman.d\/mirrorlist-arch/d' /etc/pacman.conf 2>/dev/null;

            printf "[*] Installing artix-archlinux-support...\n";
            pacman -Sy --noconfirm artix-archlinux-support;

            printf "[*] Configuring /etc/pacman.conf...\n";
            cat <<REPOS >> /etc/pacman.conf

[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
REPOS

            printf "[*] Initializing Arch keys...\n";
            pacman-key --init 2>/dev/null || true;
            pacman-key --populate archlinux;
            
            pacman -Sy --noconfirm;
        } 2>&1 | dialog --clear --title " Enabling Arch Repos " --programbox 20 80 2>&1 >/dev/tty;
        [[ ${PIPESTATUS[0]} -ne 0 ]] && _report_err ${PIPESTATUS[0]} "Arch Repos";
    fi
}

function _setup_networking {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        local is_vm=false;
        if grep -qaE "virt|vmware|kvm|qemu|oracle" /sys/class/dmi/id/product_name 2>/dev/null || \
           grep -qaE "virt|vmware|kvm|qemu|oracle" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
            is_vm=true;
        fi

        if [[ "${is_vm}" == "true" ]]; then
            _tui_msg "Networking" "Virtual Machine detected. Attempting to start dhcpcd...";
            case "${INIT}" in
                openrc) rc-service dhcpcd restart 2>/dev/null || true ;;
                runit)  sv restart dhcpcd 2>/dev/null || true ;;
                dinit)  dinitctl start dhcpcd 2>/dev/null || true ;;
                s6)     s6-rc -u change dhcpcd 2>/dev/null || true ;;
            esac;
            sleep 3;
            ping -c 1 8.8.8.8 &>/dev/null && return
        fi

        if ! ping -c 1 8.8.8.8 &>/dev/null; then
            local eth_devs;
            eth_devs=$(ip -o link show | awk -F': ' '{print $2}' | grep -vE 'lo|wlp|wlan');
            
            for dev in ${eth_devs}; do
                if [[ "$(cat /sys/class/net/${dev}/carrier 2>/dev/null)" == "1" ]]; then
                    if dialog --clear --title " Networking " --yesno "No internet detected.\n\nFound potential ethernet: ${dev}\nDo you want to try automatic DHCP?" 10 55 2>&1 >/dev/tty; then
                        (
                            printf "[*] Bringing up %s...\n" "${dev}";
                            ip link set "${dev}" up;
                            dhcpcd -n "${dev}" 2>&1;
                        ) | dialog --clear --title " DHCP " --programbox 10 70 2>&1 >/dev/tty;
                        
                        if ping -c 1 8.8.8.8 &>/dev/null; then break; fi;
                    fi
                fi
            done;
        fi

        if ! ping -c 1 8.8.8.8 &>/dev/null; then
            local wifi_dev;
            wifi_dev=$(ls /sys/class/net | grep -E '^(wlan|wlp)' | head -n 1 || echo "");

            local msg="No internet detected. Connectivity options:\n\n";
            if [[ -n "${wifi_dev}" ]]; then
                msg+="[ WIFI - iwctl ]\n1. station ${wifi_dev} scan\n2. station ${wifi_dev} get-networks\n3. station ${wifi_dev} connect [SSID]\n4. quit\n\n";
            fi
            
            msg+="[ ETHERNET / VM / DHCP ]\n";
            msg+="Try restarting the service for your INIT (${INIT}):\n";
            case "${INIT}" in
                openrc) msg+="sudo rc-service dhcpcd restart\n" ;;
                runit)  msg+="sudo sv restart dhcpcd\n" ;;
                dinit)  msg+="sudo dinitctl restart dhcpcd\n" ;;
                s6)     msg+="sudo s6-rc -u change dhcpcd\n" ;;
            esac;
            msg+="\nManual force: sudo dhcpcd [interface_name]\n\nLaunching tools...";
            _tui_msg "Networking" "${msg}";

            case "${INIT}" in
                openrc) rc-service iwd start 2>/dev/null; rc-service dhcpcd start 2>/dev/null ;;
                runit)  sv up iwd 2>/dev/null; sv up dhcpcd 2>/dev/null ;;
                dinit)  dinitctl start iwd 2>/dev/null; dinitctl start dhcpcd 2>/dev/null ;;
                s6)     s6-rc -u change iwd 2>/dev/null; s6-rc -u change dhcpcd 2>/dev/null ;;
            esac;
            
            sleep 2;
            if [[ -t 0 ]]; then
                iwctl || nmtui || true;
            fi
        fi
    fi
}

function _handle_modded_kernels {
    case "${KERNEL_CHOICE}" in
        "xanmod")
            local CPU_LEVEL=$(/lib/ld-linux-x86-64.so.2 --help | grep -E "x86-64-v[2-4] \(supported" | head -n 1 | awk '{print $1}');
            local KERNEL_PKG="";

            case "$CPU_LEVEL" in
                "x86-64-v4") KERNEL_PKG="linux-xanmod-x64v4" ;;
                "x86-64-v3") KERNEL_PKG="linux-xanmod-x64v3" ;;
                "x86-64-v2") KERNEL_PKG="linux-xanmod-x64v2" ;;
                *)           KERNEL_PKG="linux-xanmod" ;;
            esac;

            (
                pacman-key --recv-key FBA220DFC880C036 --keyserver hkp://keyserver.ubuntu.com;
                pacman-key --lsign-key FBA220DFC880C036;

                if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
                    printf "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf;
                fi

                pacman -Sy --noconfirm;

                pacman -U --noconfirm \
                    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst';

                pacman -Sy --noconfirm "$KERNEL_PKG" "${KERNEL_PKG}-headers";

                if [[ "${BOOTLOADER}" == "grub" ]]; then
                    grub-mkconfig -o /boot/grub/grub.cfg;
                elif [[ "${BOOTLOADER}" == "refind" ]]; then
                    printf "\"Boot XanMod\" \"${cmdline_opts} initrd=/boot/${ucode}.img initrd=/boot/initramfs-${KERNEL_PKG}.img\"\n" > /boot/refind_linux.conf;
                fi
            ) 2>&1 | dialog --clear --title "Xanmod Installation" --programbox 20 80 >/dev/tty ;;
        "tkg")
            _tui_msg "Kernel" "Downloading TKG source...";
            git clone https://github.com/frogging-family/linux-tkg /tmp/linux-tkg;
            chown -R "${USER_NAME:-root}": /tmp/linux-tkg;
            _tui_msg "TKG" "Source ready in /tmp/linux-tkg. Because of complexity, you can compile with: cd /tmp/linux-tkg && ./install.sh" ;;
    esac
}

function _setup_audio {
    if _tui_yesno "Audio Setup" "Would you like to configure audio server?"; then
        local ac
        ac=$( _tui_menu "Audio" "Select audio server:" "1" "Pipewire" "2" "PulseAudio" )
        local rc=0
        {
            case "${ac}" in
                1)
                    printf "[*] Installing Pipewire stack...\n"
                    pacman -S --noconfirm --needed pipewire pipewire-pulse wireplumber || rc=$?
                    printf "[*] Installing Pipewire init support for %s...\n" "${INIT}"
                    pacman -S --noconfirm --needed "pipewire-${INIT}" 2>/dev/null || true || rc=$?
                    ;;
                2)
                    printf "[*] Installing PulseAudio stack...\n"
                    pacman -S --noconfirm --needed pulseaudio pulseaudio-alsa || rc=$?
                    printf "[*] Installing PulseAudio init support for %s...\n" "${INIT}"
                    pacman -S --noconfirm --needed "pulseaudio-${INIT}" 2>/dev/null || true || rc=$?
                    ;;
            esac
        } 2>&1 | dialog --clear --title " Audio Installation " --programbox 20 80 >/dev/tty

        [[ $rc -ne 0 ]] && _report_err "$rc" "Audio"
    fi
}

function _handle_drivers {
    local pkgs=();
    local gpu_vendor=$(lspci -nn | awk -F' ' '/VGA|3D/ {print tolower($0)}' | grep -o 'nvidia\|intel\|amd' | head -n 1);
    local gpu_info=$(lspci -nn | awk -F': ' '/VGA|3D/ {print $3}' | xargs);
    local pci_id=$(lspci -n | awk -F' ' '/0300|0302/ {print $3}' | awk -F':' '{print $2}' | head -n 1);

    local is_vm="none";
    if grep -qaE "virt|vmware|kvm|qemu|oracle" /sys/class/dmi/id/product_name 2>/dev/null || \
       grep -qaE "virt|vmware|kvm|qemu|oracle" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        is_vm=$(grep -oE "vmware|qemu|kvm|oracle" /sys/class/dmi/id/product_name 2>/dev/null | head -n 1);
        [[ -z "$is_vm" ]] && is_vm="kvm";
    fi

    local final_stack="";

    if dialog --clear --title " Drivers " --yesno "Found GPU: ${gpu_info}\nVirt: ${is_vm}\n\nDo you want to install drivers?" 10 60 >/dev/tty; then

        if [[ "$is_vm" != "none" ]]; then
            case "$is_vm" in
                kvm|qemu) pkgs+=("virtio-gpu") ;;
                vmware)   pkgs+=("xf86-video-vmware") ;;
                oracle)   pkgs+=("virtualbox-guest-utils") ;;
            esac;
            final_stack="2";

        elif [[ "$gpu_vendor" == "nvidia" && -n "$pci_id" ]]; then
            local pci_hex=$((16#$pci_id));
            if (( pci_hex >= 16#1e00 )); then
                if _tui_yesno "NVIDIA Open Source Modules" "Detected newer GPU (${gpu_info}).\n\nUse OFFICIAL nvidia-open-dkms?"; then
                    pkgs+=("nvidia-open-dkms" "nvidia-utils");
                    final_stack=$(dialog --stdout --clear --title " X-Server Type " --menu "NVIDIA Open detected. Choose X-Server:" 10 50 2 "1" "xLibre-XServer" "2" "Standard X.Org");
                fi;
            fi;
        fi;

        if [[ -z "${final_stack}" ]]; then
            local DRV_CHOICE;
            DRV_CHOICE=$(dialog --stdout --clear --title " Driver Type " --menu "Choose preferred driver stack:" 12 50 2 \
                "1" "xLibre (Open Source)" \
                "2" "Standard X.Org (Proprietary)");

            [[ -z "${DRV_CHOICE}" ]] && return 0;
            final_stack="${DRV_CHOICE}";

            if [[ "$gpu_vendor" == "nvidia" ]]; then
                [[ "${final_stack}" == "2" ]] && pkgs+=("nvidia-dkms" "nvidia-utils") || pkgs+=("xlibre-video-nouveau");
            elif [[ "$gpu_vendor" == "intel" ]]; then
                [[ "${final_stack}" == "2" ]] && pkgs+=("xf86-video-intel" "intel-media-driver") || pkgs+=("xlibre-video-intel");
            elif [[ "$gpu_vendor" == "amd" ]]; then
                [[ "${final_stack}" == "2" ]] && pkgs+=("xf86-video-amdgpu" "vulkan-radeon") || pkgs+=("xlibre-video-amdgpu" "vulkan-radeon");
            else
                pkgs+=("xf86-video-vesa");
            fi;
        fi;

        [[ "${final_stack}" == "2" ]] && pkgs+=("xorg-server") || pkgs+=("xlibre-xserver");

        local rc=0;

        {
            printf "[*] Installing selected driver packages...\n";
            pacman -S --noconfirm --needed "${pkgs[@]}" || rc=$?;
        } 2>&1 | dialog --clear --title " Driver Installation " --programbox 20 80 >/dev/tty;

        if [[ $rc -ne 0 ]]; then
            if [[ "$gpu_vendor" == "nvidia" ]]; then
                _tui_msg "NVIDIA Fallback" "Selected NVIDIA driver failed. Attempting xf86-video-nouveau...";
                {
                    pacman -S --noconfirm xf86-video-nouveau || rc=$?;
                } 2>&1 | dialog --clear --title " NVIDIA Fallback " --programbox 20 80 >/dev/tty;
                [[ $rc -ne 0 ]] && _report_err "$rc" "NVIDIA Fallback";
            else
                _report_err "$rc" "Driver Installation";
            fi;
        fi;
    fi;
}

function _install_interface {
    _handle_drivers;
    local pkgs=("dbus" "dbus-${INIT}");
    local dm="lightdm";
    local common="gvfs gvfs-mtp xdg-user-dirs";

    case "${WM_DE}" in
        "xfce4")    pkgs+=("xfce4" "xfce4-goodies" ${common}) ;;
        "lxqt")     pkgs+=("lxqt" "pavucontrol-qt" ${common}); dm="sddm" ;;
        "lxde")     pkgs+=("lxde" "lxappearance" ${common}) ;;
        "hyprland") pkgs+=("hyprland" "seatd" "seatd-${INIT}" "xdg-desktop-portal-hyprland" "foot") ;;
        "niri")     pkgs+=("niri" "seatd" "seatd-${INIT}" "foot") ;;
        "i3wm")     pkgs+=("i3-wm" "i3status" "i3lock" "xterm") ;;
        "dwm"|"vxvm") pkgs+=("libx11" "libxft" "libxinerama" "xorg-server-devel" "base-devel" "git" "imlib2" "xorg-xinit" "xorg-xsetroot") ;;
    esac

    if [[ ${#pkgs[@]} -gt 2 ]]; then
        local rc=0

        {
            printf "[*] Refreshing databases (Multilib/Extra)...\n";
            pacman -Sy --noconfirm || rc=$?;

            if [[ "${DRV_CHOICE:-2}" == "1" ]]; then
                local x_ver;
                x_ver=$(pacman -Si xorg-server 2>/dev/null | grep Version | awk '{print $3}' | cut -d'-' -f1 || echo "21.1.13");
                printf "\n" | pacman -S --noconfirm --needed --assume-installed "xorg-server=${x_ver}" "${pkgs[@]}" || rc=$?;
            else
                printf "\n" | pacman -S --noconfirm --needed "${pkgs[@]}" || rc=$?;
            fi
        } 2>&1 | dialog --clear --title " Interface Installation " --programbox 20 80 >/dev/tty;

        [[ $rc -ne 0 ]] && _report_err "$rc" "Interface"
    fi

    case "${INIT}" in
        openrc) rc-update add dbus default; rc-service dbus start 2>/dev/null || true ;;
        runit)  ln -s /etc/runit/sv/dbus /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
        dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../dbus /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
        s6)     s6-rc-bundle-update add default dbus 2>/dev/null || true ;;
    esac

    case "${WM_DE}" in
        dwm|vxvm)
            (
                local repo_url="git://git.suckless.org/dwm"
                [[ "${WM_DE}" =~ ^vxv[m|w]$ ]] && repo_url="https://codeberg.org/wh1tepearl/vxwm"

                git clone "${repo_url}" "/tmp/${WM_DE}"
                cd "/tmp/${WM_DE}" || exit 1
                [[ -f config.def.h ]] && cp config.def.h config.h
                make clean install

                mkdir -p /usr/share/xsessions
                printf "[Desktop Entry]\nName=%s\nExec=%s\nType=Application\n" "${WM_DE}" "${WM_DE}" > "/usr/share/xsessions/${WM_DE}.desktop"

                if [[ -n "${USER_NAME:-}" ]]; then
                    local user_home="/home/${USER_NAME}"
                    printf "while true; do xsetroot -name \"\$(date '+%%H:%%M')\"; sleep 60; done &\nexec %s\n" "${WM_DE}" > "${user_home}/.xinitrc"
                    chown "${USER_NAME}:${USER_NAME}" "${user_home}/.xinitrc"
                    chmod +x "${user_home}/.xinitrc"
                fi
            ) 2>&1 | dialog --clear --title "Compiling ${WM_DE}" --programbox 20 80 >/dev/tty
            ;;

        hyprland|niri)
            case "${INIT}" in
                openrc) rc-update add seatd default; rc-service seatd start 2>/dev/null || true ;;
                runit)  ln -s /etc/runit/sv/seatd /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../seatd /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
                s6)     s6-rc-bundle-update add default seatd 2>/dev/null || true ;;
            esac
            [[ -n "${USER_NAME:-}" ]] && usermod -aG video,render,input,seat "${USER_NAME}"
            ;;

        xfce4|lxqt|lxde)
            (
                pacman -S --noconfirm "${dm}" "${dm}-${INIT}"
                [[ "${dm}" == "lightdm" ]] && pacman -S --noconfirm lightdm-gtk-greeter
                case "${INIT}" in
                    openrc) rc-update add "${dm}" default ;;
                    runit)  ln -s "/etc/runit/sv/${dm}" /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                    dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../${dm} /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
                    s6)     s6-rc-bundle-update add default "${dm}" 2>/dev/null || true ;;
                esac
            ) 2>&1 | dialog --clear --title " Display Manager Setup " --programbox 20 80 >/dev/tty
            ;;
    esac
}

function _install_bonus_tools {
    if _tui_yesno "Extras" "Enter bonus tools menu?"; then

        if _tui_yesno "Git" "Install Git & Base-Devel?"; then
            ( pacman -S --noconfirm git base-devel ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
        fi

        if _tui_yesno "Codecs" "Install Multimedia Codecs (essential for video/audio)?"; then
            ( pacman -S --noconfirm alsa-utils alsa-plugins gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
        fi

        if _tui_yesno "Firewall" "Install UFW?"; then
            ( pacman -S --noconfirm ufw "ufw-${INIT}" ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
            case "${INIT}" in
                openrc) rc-update add ufw default ;;
                runit)  ln -s /etc/runit/sv/ufw /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../ufw /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
                s6)     s6-rc-bundle-update add default ufw 2>/dev/null || true ;;
            esac;
        fi

        if _tui_yesno "Bluetooth" "Install Bluetooth stack (Bluez)?"; then
            ( pacman -S --noconfirm bluez bluez-utils "bluez-${INIT}" ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
            case "${INIT}" in
                openrc) rc-update add bluetooth default ;;
                runit)  ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/ 2>/dev/null || true ;;
                dinit)  mkdir -p /etc/dinit.d/boot.d; ln -s ../bluetoothd /etc/dinit.d/boot.d/ 2>/dev/null || true ;;
            esac;
        fi

        if _tui_yesno "Flatpak" "Install Flatpak support?"; then
            ( pacman -S --noconfirm flatpak ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
        fi

        if _tui_yesno "Zram" "Install Zram-tools for better RAM management?"; then
            ( pacman -S --noconfirm zram-tools "zram-tools-${INIT}" ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
            [[ "${INIT}" == "openrc" ]] && rc-update add zramd default;
        fi

        if _tui_yesno "Fastfetch" "Install Fastfetch?"; then
            ( pacman -S --noconfirm fastfetch ) 2>&1 | dialog --clear --title "Extras" --programbox 20 80 2>&1 >/dev/tty;
        fi

        if [[ "${INIT}" == "runit" ]] && _tui_yesno "rsvc" "Install SashexSRB's rsvc?"; then
            ( git clone https://github.com/SashexSRB/rsvc /tmp/rsvc && cd /tmp/rsvc && make && make install ) 2>&1 | dialog --clear --title "rsvc Installation" --programbox 20 80 2>&1 >/dev/tty;
        fi
    fi;
}
main {
    [[ "${EUID}" -ne 0 ]] && _error_exit "must be run as root";

    _setup_networking        || _error_exit "networking";
    _enable_arch_repos       || _error_exit "repos";
    _handle_modded_kernels   || _error_exit "kernels";
    _install_interface       || _error_exit "interface";
    _setup_audio             || _error_exit "audio";
    _install_bonus_tools     || _error_exit "bonus tools";

    touch /var/lib/artix-firstboot-done;
    rm -f /etc/profile.d/firstboot.sh;

    _tui_msg "Finish" "Setup complete. Please reboot."
}
main;