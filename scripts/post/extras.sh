#!/usr/bin/env bash
set -Eeuo pipefail

install_extras() {
    local selected=" ${EXTRAS:-} " pkgs=() init="${INIT:-openrc}"

    [[ "${selected}" == *" git "* ]] && pkgs+=(git base-devel)

    if [[ "${selected}" == *" rsvc "* ]]; then
        if [[ "${init}" != 'runit' ]]; then
            log_warn "rsvc only supported on runit systems. Skipping."
        else
            [[ "${selected}" == *" git "* ]] || pkgs+=(git base-devel)
        fi
    fi

    [[ "${selected}" == *" flatpak "* ]] && pkgs+=(flatpak)
    [[ "${selected}" == *" fastfetch "* ]] && pkgs+=(fastfetch)
    [[ "${selected}" == *" ufw "* ]] && pkgs+=(ufw "ufw-${init}")
    [[ "${selected}" == *" bluez "* ]] && pkgs+=(bluez bluez-utils "bluez-${init}")
    [[ "${selected}" == *" zram-tools "* ]] && pkgs+=(zram-tools "zram-tools-${init}")
    [[ "${selected}" == *" fzf "* ]] && pkgs+=(fzf)
    [[ "${selected}" == *" zoxide "* ]] && pkgs+=(zoxide)
    [[ "${selected}" == *" starship "* ]] && pkgs+=(starship)
    [[ "${selected}" == *" eza "* ]] && pkgs+=(eza)
    [[ "${selected}" == *" btop "* ]] && pkgs+=(btop)
    [[ "${selected}" == *" htop "* ]] && pkgs+=(htop)
    [[ "${selected}" == *" nvtop "* ]] && pkgs+=(nvtop)
    [[ "${selected}" == *" tmux "* ]] && pkgs+=(tmux)
    [[ "${selected}" == *" usb_modeswitch "* ]] && pkgs+=(usb_modeswitch)

    if [[ ${#pkgs[@]} -eq 0 && "${selected}" != *" rsvc "* ]]; then return 0; fi

    log_info "Installing extras..."
    [[ ${#pkgs[@]} -gt 0 ]] && pacman -S --noconfirm --needed "${pkgs[@]}"

    [[ "${selected}" == *" ufw "* ]] && enable_service ufw
    [[ "${selected}" == *" bluez "* ]] && enable_service bluetooth
    [[ "${selected}" == *" zram-tools "* ]] && enable_service zramd

    if [[ "${selected}" == *" rsvc "* && "${init}" == 'runit' ]]; then
        log_info "Installing rsvc..."
        git clone https://github.com/SashexSRB/rsvc /tmp/rsvc || true
        ( cd /tmp/rsvc && make && make install )
    fi

    log_info "Extras installation complete."
}