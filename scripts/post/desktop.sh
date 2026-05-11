install_desktop() {
    local wm_de;
    local init;
    local display_manager;
    local kde_profile='none';
    local pkgs=();

    wm_de="${WM_DE:-none}";
    init="${INIT:-openrc}";
    display_manager="${DISPLAY_MANAGER:-none}";

    if [[ "${wm_de}" == 'kde' ]]; then
        kde_profile="$(state_get KDE_PROFILE desktop)";
    fi

    if [[ "${wm_de}" != 'kde' ]] \
        && [[ "${kde_profile}" != 'none' ]]; then

        printf '[*] Ignoring KDE profile for non-KDE desktop: %s\n' \
            "${wm_de}";

        kde_profile='none';
    fi

    printf '[*] Verifying dbus service...\n';

    if ! service_exists dbus; then
        printf '[*] dbus service is missing for init: %s\n' \
            "${init}" \
            >&2;

        return 1;
    fi

    enable_service dbus;

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

        kde)
            case "${kde_profile}" in
                minimal)
                    printf '[*] Installing KDE minimal profile...\n';

                    pkgs+=(
                        plasma-desktop
                        dolphin
                        konsole
                        xdg-desktop-portal-kde
                    )
                    ;;

                full|edge)
                    printf '[*] Installing KDE full profile...\n';

                    pkgs+=(
                        plasma
                        kde-applications
                        xdg-desktop-portal-kde
                    )
                    ;;

                desktop|*)
                    printf '[*] Installing KDE desktop profile...\n';

                    pkgs+=(
                        plasma
                        xdg-desktop-portal-kde
                    )
                    ;;
            esac
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

                if ! pacman -Sy --noconfirm archlinux-keyring; then
                    printf '[!] Failed to install Arch Linux keyring.\n' >&2;
                    return 1;
                fi
            fi

            if ! pacman-key --init; then
                printf '[!] Failed to initialize pacman keys.\n' >&2;
                return 1;
            fi

            if ! pacman-key --populate artix archlinux; then
                printf '[!] Failed to populate pacman keys.\n' >&2;
                return 1;
            fi

            # Now, you may ask, why the this? Simple, pacman likes to cache things. Corrupted packages are a big no-no.
            rm -f \
                /var/cache/pacman/pkg/chaotic-keyring* \
                /var/cache/pacman/pkg/chaotic-mirrorlist*

            if ! pacman-key \
                --recv-key 3056513887B78AEB \
                --keyserver hkp://keyserver.ubuntu.com; then

                printf '[!] Failed to receive Chaotic-AUR signing key.\n' >&2;
                return 1;
            fi

            if ! pacman-key \
                --lsign-key 3056513887B78AEB; then

                printf '[!] Failed to locally sign Chaotic-AUR key.\n' >&2;
                return 1;
            fi

            printf '[*] Installing Chaotic-AUR bootstrap packages...\n';

            if ! pacman -U --noconfirm \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
                'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'; then

                printf '[!] Failed to install Chaotic-AUR bootstrap packages.\n' >&2;
                return 1;
            fi

            if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
                cat <<'EOF' >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
            fi

            if ! pacman -Syu --noconfirm; then
                printf '[!] Failed to synchronize packages for Chaotic-AUR.\n' >&2;
                return 1;
            fi

            pkgs+=(
                foot
                waybar
                wofi
                xdg-desktop-portal-hyprland

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

    if ! pacman -S \
        --noconfirm \
        --needed \
        "${pkgs[@]}"; then

        printf '[!] Failed to install desktop packages.\n' >&2;
        return 1;
    fi

    if [[ "${wm_de}" == 'mango' ]]; then
        printf '[*] Building MangoWM from AUR...\n';

        local build_dir='/tmp/mangowm-git';

        rm -rf "${build_dir}";

        if ! git clone \
            'https://aur.archlinux.org/mangowm-git.git' \
            "${build_dir}"; then

            printf '[!] Failed to clone MangoWM repository.\n' >&2;
            return 1;
        fi

        chown -R "${USER_NAME}:${USER_NAME}" \
            "${build_dir}";

        if ! su - "${USER_NAME}" -c "
            cd '${build_dir}' &&
            makepkg --noconfirm
        "; then

            printf '[!] Failed to build MangoWM package.\n' >&2;
            return 1;
        fi

        if ! pacman -U --noconfirm \
            "${build_dir}"/*.pkg.tar.*; then

            printf '[!] Failed to install MangoWM package.\n' >&2;
            return 1;
        fi

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