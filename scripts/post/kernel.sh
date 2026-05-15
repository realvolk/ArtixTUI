#!/usr/bin/env bash
set -Eeuo pipefail

install_kernel_bazzite() {
    log_info "Building linux-bazzite-bin from AUR..."
    local build_dir='/tmp/linux-bazzite-bin'
    rm -rf "${build_dir}"
    git clone 'https://aur.archlinux.org/linux-bazzite-bin.git' "${build_dir}" || {
        log_error "Failed to clone linux-bazzite-bin AUR repo."
        return 1
    }
    chown -R "${USER_NAME}:${USER_NAME}" "${build_dir}"
    su - "${USER_NAME}" -c "cd '${build_dir}' && makepkg -s --noconfirm --needed" || {
        log_error "Failed to build linux-bazzite-bin."
        return 1
    }
    pacman -U --noconfirm "${build_dir}"/*.pkg.tar.* || {
        log_error "Failed to install linux-bazzite-bin package."
        return 1
    }
    rm -rf "${build_dir}"
    log_info "Bazzite kernel installed."
}