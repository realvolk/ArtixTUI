#!/usr/bin/env bash
set -Eeuo pipefail;

die() {
    local reason="${1:-unknown error}";

    printf '\n\e[1;31m[!] %s\e[0m\n' "${reason^}" >&2;
    exit 1;
}

warn() {
    local message="${1:-warning}";

    printf '\n\e[1;33m[*] %s\e[0m\n' "${message^}" >&2;
}

info() {
    local message="${1:-info}";

    printf '\n\e[1;34m[*] %s\e[0m\n' "${message}" >&2;
}

require_root() {
    [[ "${EUID}" -eq 0 ]] \
        || die 'must be run as root';
}

require_efi() {
    [[ -d /sys/firmware/efi ]] \
        || die 'system is not booted in UEFI mode';
}

require_internet() {
    if ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        return 0;
    fi;

    if [[ "${ALLOW_OFFLINE:-no}" == "yes" ]]; then
        warn 'continuing in offline mode';
        return 0;
    fi;

    die 'no internet connection';
}

get_partition_name() {
    local disk="${1}";
    local partition="${2}";

    if [[ "${disk}" =~ ^/dev/(nvme|mmcblk|loop) ]]; then
        printf '%sp%s\n' "${disk}" "${partition}";
    else
        printf '%s%s\n' "${disk}" "${partition}";
    fi
}

command_exists() {
    command -v "${1}" &>/dev/null;
}

ensure_dirs() {
    mkdir -p \
        /tmp/artix-installer \
        /tmp/artix-installer/stages \
        /tmp/artix-installer/logs;
}