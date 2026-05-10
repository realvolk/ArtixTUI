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

            if [[ "$(state_get ENABLE_ARCH_REPOS no)" == 'yes' ]]; then
                printf '[*] Installing Arch Linux keyring...\n';

                pacman -Sy --noconfirm archlinux-keyring
            fi

            pacman-key --init
            pacman-key --populate artix archlinux

            # Now, you may ask, why the this? Simple, pacman likes to cache things. Corrupted packages are a big no-no.
            rm -f \
                /var/cache/pacman/pkg/chaotic-keyring* \
                /var/cache/pacman/pkg/chaotic-mirrorlist*

            pacman-key \
                --recv-key 3056513887B78AEB \
                --keyserver hkp://keyserver.ubuntu.com

            pacman-key \
                --lsign-key 3056513887B78AEB

            printf '[*] Installing Chaotic-AUR bootstrap packages...\n';

            pacman -U --noconfirm \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

            if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            fi

            pacman -Sy --noconfirm

            pkgs+=(
                foot
                waybar
                wofi
                xdg-desktop-portal-wlr

                seatd
                "seatd-${init}"

                base-devel
                git
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

    if [[ "${wm_de}" == 'mango' ]]; then
        printf '[*] Building MangoWM from AUR...\n';

        local build_dir='/tmp/mangowm-git';

        rm -rf "${build_dir}";

        git clone \
            'https://aur.archlinux.org/mangowm-git.git' \
            "${build_dir}";

        chown -R "${USER_NAME}:${USER_NAME}" \
            "${build_dir}";

        sudo -u "${USER_NAME}" \
            bash -c "
                cd '${build_dir}' &&
                makepkg -si --noconfirm
            ";

        rm -rf "${build_dir}";
    fi

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
            printf '[*] Verifying seatd service...\n'

            if ! service_exists seatd; then
                printf '[!] seatd service is missing for init: %s\n' \
                    "${init}" \
                    >&2;

                return 1;
            fi

            enable_service seatd
            ;;
    esac

    printf '\n[*] Desktop installation complete.\n';
}