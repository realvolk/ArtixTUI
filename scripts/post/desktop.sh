install_desktop() {
    local wm_de;
    local init;
    local display_manager;
    local pkgs=();

    wm_de="${WM_DE:-none}";
    init="${INIT:-openrc}";
    display_manager="${DISPLAY_MANAGER:-none}";

    case "${wm_de}" in
        xfce4)
            pkgs+=(
                xfce4
                xfce4-goodies
            )
            ;;

        lxqt)
            pkgs+=(
                lxqt
            )
            ;;

        lxde)
            pkgs+=(
                lxde
                lxappearance
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

        mango)
            printf '[*] Setting up Chaotic-AUR for MangoWM...\n';

            pacman-key --init;
            pacman-key --populate artix;

            pacman-key \
                --recv-keys FBA220DFC880C036 \
                --keyserver hkp://keyserver.ubuntu.com;

            pacman-key \
                --lsign-key FBA220DFC880C036;

            pacman -U --noconfirm \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst';

            if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            fi

            pacman -Sy --noconfirm;

            pkgs+=(
                mangowm
                foot
                waybar
                wofi
                xdg-desktop-portal-wlr

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
            )
            ;;

        dwm)
            pkgs+=(
                dwm
                dmenu
                xterm
            )
            ;;

        icewm)
            pkgs+=(
                icewm
                icewm-themes
                xterm
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

    case "${display_manager}" in
        lightdm)
            enable_service lightdm
            ;;

        sddm)
            enable_service sddm
            ;;
    esac

    case "${wm_de}" in
        hyprland|mango|niri|sway)
            enable_service seatd
            ;;
    esac

    printf '\n[*] Desktop installation complete.\n';
}