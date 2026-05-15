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
    useradd -m builduser 2>/dev/null || true
    chown -R builduser:builduser "${build_dir}"
    su builduser -c "cd '${build_dir}' && makepkg -s --noconfirm --needed --skippgpcheck" || {
        log_error "Failed to build linux-bazzite-bin."
        return 1
    }
    pacman -U --noconfirm "${build_dir}"/*.pkg.tar.* || {
        log_error "Failed to install linux-bazzite-bin package."
        return 1
    }
    local kver
    kver=$(ls /usr/lib/modules | grep bazzite | head -1)
    if [[ -n "${kver}" && -f "/usr/lib/modules/${kver}/vmlinuz" ]]; then
        cp "/usr/lib/modules/${kver}/vmlinuz" "/boot/vmlinuz-linux-bazzite"
    fi
    rm -rf "${build_dir}"
    log_info "Bazzite kernel installed."
}