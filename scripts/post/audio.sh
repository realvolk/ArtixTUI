#!/usr/bin/env bash
set -Eeuo pipefail
setup_audio() {
    local audio_stack="${AUDIO_STACK:-pipewire}" pkgs=()
    case "${audio_stack}" in
        pipewire)
            if pacman -Qq jack &>/dev/null || pacman -Qq jack2 &>/dev/null; then
                log_info "Replacing jack/jack2 with pipewire-jack..."
                pacman -Rdd --noconfirm jack jack2 2>/dev/null || true
            fi
            pkgs+=(pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber alsa-utils pavucontrol rtkit) ;;
        pulseaudio)
            pkgs+=(pulseaudio pulseaudio-alsa alsa-utils pavucontrol) ;;
        none) return 0 ;;
    esac
    log_info "Installing audio packages..."
    pacman -S --noconfirm --needed "${pkgs[@]}" || { log_warn "Failed to install audio packages."; return 1; }
}