#!/usr/bin/env bash
set -Eeuo pipefail;

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

_ensure_log_dirs() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    [[ -d /mnt ]] && mkdir -p "$(dirname "${CHROOT_LOG}")" 2>/dev/null || true
}

log_info() {
    _ensure_log_dirs
    printf '\e[1;34m[*] %s\e[0m\n' "$*" | tee -a "${LOG_FILE}" >&2
    [[ -d /mnt ]] && printf '[*] %s\n' "$*" >> "${CHROOT_LOG}" 2>/dev/null || true
}

log_warn() {
    _ensure_log_dirs
    printf '\e[1;33m[!] %s\e[0m\n' "$*" | tee -a "${LOG_FILE}" >&2
}

log_error() {
    _ensure_log_dirs
    printf '\e[1;31m[✗] %s\e[0m\n' "$*" | tee -a "${LOG_FILE}" >&2
}

die() {
    local reason="${1:-unknown error}"
    log_error "${reason^}"
    exit 1
}

warn() {
    local message="${1:-warning}"
    log_warn "${message^}"
}

info() {
    local message="${1:-info}"
    log_info "${message}"
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die 'must be run as root'
}

require_efi() {
    [[ -d /sys/firmware/efi ]] || die 'system is not booted in UEFI mode'
}

require_internet() {
    if command -v curl &>/dev/null; then
        if curl -fsSL --max-time 5 https://1.1.1.1 &>/dev/null; then
            return 0
        fi
    elif ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        return 0
    fi

    if [[ "${ALLOW_OFFLINE:-no}" == "yes" ]]; then
        warn 'continuing in offline mode'
        return 0
    fi

    die 'no internet connection'
}

get_partition_name() {
    local disk="${1}"
    local partition="${2}"
    if [[ "${disk}" =~ ^/dev/(nvme|mmcblk|loop) ]]; then
        printf '%sp%s\n' "${disk}" "${partition}"
    else
        printf '%s%s\n' "${disk}" "${partition}"
    fi
}

command_exists() {
    command -v "${1}" &>/dev/null
}

ensure_dirs() {
    mkdir -p /tmp/artix-installer/{stages,logs}
}