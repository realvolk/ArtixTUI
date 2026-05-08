install_extras() {
    local selected;
    local pkgs=();
    local init;

    selected="${EXTRAS:-}";
    init="${INIT:-openrc}";

    [[ "${selected}" == *git* ]] && \
        pkgs+=(git base-devel);

    [[ "${selected}" == *flatpak* ]] && \
        pkgs+=(flatpak);

    [[ "${selected}" == *fastfetch* ]] && \
        pkgs+=(fastfetch);

    [[ "${selected}" == *ufw* ]] && \
        pkgs+=(ufw "ufw-${init}");

    [[ "${selected}" == *bluez* ]] && \
        pkgs+=(
            bluez
            bluez-utils
            "bluez-${init}"
        );

    [[ "${selected}" == *zram-tools* ]] && \
        pkgs+=(
            zram-tools
            "zram-tools-${init}"
        );

    [[ "${selected}" == *fzf* ]] && \
        pkgs+=(fzf);

    [[ "${selected}" == *zoxide* ]] && \
        pkgs+=(zoxide);

    [[ "${selected}" == *starship* ]] && \
        pkgs+=(starship);

    [[ "${selected}" == *eza* ]] && \
        pkgs+=(eza);

    [[ "${selected}" == *btop* ]] && \
        pkgs+=(btop);

    [[ "${selected}" == *htop* ]] && \
        pkgs+=(htop);

    [[ "${selected}" == *nvtop* ]] && \
        pkgs+=(nvtop);

    [[ "${selected}" == *tmux* ]] && \
        pkgs+=(tmux);

    [[ "${selected}" == *usb_modeswitch* ]] && \
        pkgs+=(usb_modeswitch);

    [[ ${#pkgs[@]} -eq 0 ]] && \
        [[ "${selected}" != *rsvc* ]] && \
        return 0;

    printf '[*] Installing extras...\n';

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        pacman -S \
            --noconfirm \
            --needed \
            "${pkgs[@]}";
    fi

    [[ "${selected}" == *ufw* ]] && \
        enable_service ufw;

    [[ "${selected}" == *bluez* ]] && \
        enable_service bluetooth;

    [[ "${selected}" == *zram-tools* ]] && \
        enable_service zramd;

    if [[ "${selected}" == *rsvc* ]]; then
        if [[ "${init}" != 'runit' ]]; then
            printf '\n[!] rsvc is only supported on runit systems.\n';
        else
            printf '\n[*] Installing rsvc...\n';

            git clone \
                https://github.com/SashexSRB/rsvc \
                /tmp/rsvc \
                || true;

            (
                cd /tmp/rsvc \
                    && make \
                    && make install
            );
        fi
    fi

    printf '\n[*] Extras installation complete.\n';
}