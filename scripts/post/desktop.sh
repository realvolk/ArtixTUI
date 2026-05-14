#!/usr/bin/env bash
set -Eeuo pipefail

install_desktop() {
    local wm_de init display_manager kde_profile
    local -a pkgs=()

    wm_de="$(printf '%s' "${WM_DE:-none}" | tr -d '[:space:]')"
    init="$(printf '%s' "${INIT:-openrc}" | tr -d '[:space:]')"
    display_manager="$(printf '%s' "${DISPLAY_MANAGER:-none}" | tr -d '[:space:]')"
    kde_profile='none'

    if [[ "${wm_de}" == 'kde' ]]; then
        kde_profile="$(state_get KDE_PROFILE desktop)"
    elif [[ "${kde_profile}" != 'none' ]]; then
        log_info "Ignoring KDE profile for non-KDE desktop: ${wm_de}"
        kde_profile='none'
    fi

    log_info "Verifying dbus service..."
    service_exists dbus || { log_error "dbus service missing for init: ${init}"; return 1; }
    enable_service dbus

    case "${wm_de}" in
        xfce4)    pkgs+=(xfce4 xfce4-goodies) ;;
        lxqt)     pkgs+=(lxqt) ;;
        lxde)     pkgs+=(lxde lxappearance) ;;
        i3wm)     pkgs+=(i3-wm i3status i3lock dmenu xterm) ;;
        dwm)      pkgs+=(dwm dmenu xterm) ;;
        icewm)    pkgs+=(icewm icewm-themes xterm) ;;
        none)     return 0 ;;

        kde)
            case "${kde_profile}" in
                minimal)       pkgs+=(plasma-desktop dolphin konsole xdg-desktop-portal-kde) ;;
                full|edge)     pkgs+=(plasma kde-applications xdg-desktop-portal-kde) ;;
                desktop|*)     pkgs+=(plasma xdg-desktop-portal-kde) ;;
            esac ;;

        hyprland)
            pkgs+=(hyprland foot waybar wofi xdg-desktop-portal-hyprland seatd "seatd-${init}") ;;

        niri)
            pkgs+=(niri foot waybar fuzzel xdg-desktop-portal-gtk seatd "seatd-${init}") ;;

        sway)
            pkgs+=(sway swaybg swaylock swayidle foot waybar wofi xdg-desktop-portal-wlr seatd "seatd-${init}") ;;

        mango)
            log_info "Setting up Chaotic-AUR for MangoWM..."
            [[ "$(state_get ENABLE_ARCH_REPOS no)" == 'yes' ]] && pacman -S --noconfirm archlinux-keyring || { log_error "Failed to install Arch Linux keyring."; return 1; }
            pacman-key --init || { log_error "Failed to initialize pacman keys."; return 1; }
            pacman-key --populate artix archlinux || { log_error "Failed to populate pacman keys."; return 1; }
            rm -f /var/cache/pacman/pkg/chaotic-keyring* /var/cache/pacman/pkg/chaotic-mirrorlist*
            pacman-key --recv-key 3056513887B78AEB --keyserver hkp://keyserver.ubuntu.com || { log_error "Failed to receive Chaotic-AUR key."; return 1; }
            pacman-key --lsign-key 3056513887B78AEB || { log_error "Failed to locally sign Chaotic-AUR key."; return 1; }
            pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || { log_error "Failed to install Chaotic-AUR bootstrap packages."; return 1; }
            grep -q '^\[chaotic-aur\]' /etc/pacman.conf || cat <<'EOF' >> /etc/pacman.conf
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            pacman -Sy --noconfirm || { log_error "Failed to sync package databases."; return 1; }
            pkgs+=(foot waybar wofi xdg-desktop-portal-hyprland seatd "seatd-${init}" base-devel git) ;;
    esac

    case "${display_manager}" in
        lightdm) pkgs+=(lightdm lightdm-gtk-greeter "lightdm-${init}") ;;
        sddm)    pkgs+=(sddm "sddm-${init}") ;;
    esac

    log_info "Installing desktop environment..."
    log_info "Desktop package list:"
    printf ' - %s\n' "${pkgs[@]}"
    pacman -S --noconfirm --needed "${pkgs[@]}" || { log_error "Failed to install desktop packages."; return 1; }

    if [[ "${wm_de}" == 'mango' ]]; then
        log_info "Building MangoWM from AUR..."
        local build_dir='/tmp/mangowm-git'
        rm -rf "${build_dir}"
        git clone 'https://aur.archlinux.org/mangowm-git.git' "${build_dir}" || { log_error "Failed to clone MangoWM repo."; return 1; }
        chown -R "${USER_NAME}:${USER_NAME}" "${build_dir}"
        su - "${USER_NAME}" -c "cd '${build_dir}' && makepkg --noconfirm" || { log_error "Failed to build MangoWM."; return 1; }
        pacman -U --noconfirm "${build_dir}"/*.pkg.tar.* || { log_error "Failed to install MangoWM package."; return 1; }
        rm -rf "${build_dir}"
    fi

    case "${display_manager}" in
        lightdm) enable_service lightdm || { log_error "Failed to enable LightDM."; return 1; } ;;
        sddm)    enable_service sddm || { log_error "Failed to enable SDDM."; return 1; } ;;
    esac

    case "${wm_de}" in
        hyprland|mango|niri|sway)
            log_info "Verifying seatd service..."
            service_exists seatd || { log_error "seatd service missing for init: ${init}"; return 1; }
            enable_service seatd || { log_error "Failed to enable seatd."; return 1; } ;;
    esac

    log_info "Desktop installation complete."
}