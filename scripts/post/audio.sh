#!/usr/bin/env bash
set -Eeuo pipefail
setup_audio() {
    local audio_stack="${AUDIO_STACK:-pipewire}" pkgs=()
    case "${audio_stack}" in
        pipewire)
            pkgs+=(pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber alsa-utils pavucontrol rtkit) ;;
        pulseaudio)
            pkgs+=(pulseaudio pulseaudio-alsa alsa-utils pavucontrol) ;;
        none) return 0 ;;
    esac
    log_info "Installing audio packages..."
    pacman -S --noconfirm --needed "${pkgs[@]}" || { log_warn "Failed to install audio packages."; return 1; }
}