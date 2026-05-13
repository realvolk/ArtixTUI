#!/usr/bin/env bash
set -Eeuo pipefail

setup_networking() {
    local network_stack="${NETWORK_STACK:-dhcpcd+iwd}" init="${INIT:-openrc}" pkgs=()
    case "${network_stack}" in
        networkmanager) pkgs+=(networkmanager "networkmanager-${init}") ;;
        connman)        pkgs+=(connman "connman-${init}") ;;
        dhcpcd+iwd)     pkgs+=(dhcpcd iwd "dhcpcd-${init}" "iwd-${init}") ;;
        none) return 0 ;;
    esac

    pacman -S --noconfirm --needed "${pkgs[@]}"

    case "${network_stack}" in
        networkmanager) enable_service NetworkManager ;;
        connman)        enable_service connmand ;;
        dhcpcd+iwd)     enable_service dhcpcd; enable_service iwd ;;
    esac
}