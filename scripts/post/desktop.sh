install_desktop() {
    local wm_de;
    local init;
    local pkgs=();

    wm_de="${WM_DE:-none}";
    init="${INIT:-openrc}";

    case "${wm_de}" in
        xfce4)
            pkgs+=(
                xfce4
                xfce4-goodies

                lightdm
                lightdm-gtk-greeter
                "lightdm-${init}"
            )
            ;;

        lxqt)
            pkgs+=(
                lxqt

                sddm
                "sddm-${init}"
            )
            ;;

        lxde)
            pkgs+=(
                lxde
                lxappearance

                lightdm
                lightdm-gtk-greeter
                "lightdm-${init}"
            )
            ;;

        hyprland)
            pkgs+=(
                hyprland
                foot
                waybar
                wofi
                xdg-desktop-portal-hyprland

                seatd
                "seatd-${init}"
            )
            ;;

        niri)
            pkgs+=(
                niri
                foot
                waybar
                fuzzel
                xdg-desktop-portal-gtk

                seatd
                "seatd-${init}"
            )
            ;;

        sway)
            pkgs+=(
                sway
                swaybg
                swaylock
                swayidle
                foot
                waybar
                wofi
                xdg-desktop-portal-wlr

                seatd
                "seatd-${init}"
            )
            ;;

        i3wm)
            pkgs+=(
                i3-wm
                i3status
                i3lock
                dmenu
                xterm

                lightdm
                lightdm-gtk-greeter
                "lightdm-${init}"
            )
            ;;

        dwm)
            pkgs+=(
                dwm
                dmenu
                xterm

                lightdm
                lightdm-gtk-greeter
                "lightdm-${init}"
            )
            ;;

        icewm)
            pkgs+=(
                icewm
                icewm-themes
                xterm

                lightdm
                lightdm-gtk-greeter
                "lightdm-${init}"
            )
            ;;

        none)
            return 0
            ;;
    esac

    printf '[*] Installing desktop environment...\n';

    pacman -S \
        --noconfirm \
        --needed \
        "${pkgs[@]}";

    case "${wm_de}" in
        xfce4|lxde|i3wm|dwm|icewm)
            enable_service lightdm
            ;;

        lxqt)
            enable_service sddm
            ;;

        hyprland|niri|sway)
            enable_service seatd
            ;;
    esac

    printf '\n[*] Desktop installation complete.\n';
}