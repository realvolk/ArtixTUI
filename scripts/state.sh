#!/usr/bin/env bash
set -Eeuo pipefail;

readonly STATE_ROOT="/tmp/artix-installer";
readonly STATE_FILE="${STATE_ROOT}/state.conf";

readonly STAGE_DIR="${STATE_ROOT}/stages";
readonly LOG_DIR="${STATE_ROOT}/logs";

mkdir -p \
    "${STATE_ROOT}" \
    "${STAGE_DIR}" \
    "${LOG_DIR}";

state_save() {
    cat <<EOF > "${STATE_FILE}"
DISK="${DISK:-}"
FS_TYPE="${FS_TYPE:-}"
INIT="${INIT:-}"
USE_LUKS="${USE_LUKS:-}"
LUKS_PASS="${LUKS_PASS:-}"
BOOTLOADER="${BOOTLOADER:-}"
KERNEL_CHOICE="${KERNEL_CHOICE:-}"
KERNEL_IMAGE="${KERNEL_IMAGE:-}"
INITRAMFS_IMAGE="${INITRAMFS_IMAGE:-}"
MICROCODE_IMAGE="${MICROCODE_IMAGE:-}"
WM_DE="${WM_DE:-}"
USER_NAME="${USER_NAME:-}"
USER_PASS="${USER_PASS:-}"
ROOT_PASS="${ROOT_PASS:-}"
USER_SHELL="${USER_SHELL:-/bin/bash}"
NETWORK_STACK="${NETWORK_STACK:-dhcpcd+iwd}"
ALLOW_OFFLINE="${ALLOW_OFFLINE:-no}"
X_STACK="${X_STACK:-xorg}"
ENABLE_ARCH_REPOS="${ENABLE_ARCH_REPOS:-no}"
EOF

    chmod 600 "${STATE_FILE}";
}

state_load() {
    [[ -f "${STATE_FILE}" ]] || return 0;
    source "${STATE_FILE}";
}

state_get() {
    local key="${1}";
    local default="${2:-}";

    printf '%s\n' "${!key:-${default}}";
}

state_set() {
    local key="${1}";
    local value="${2}";

    export "${key}=${value}";

    touch "${STATE_FILE}";

    if grep -qE "^${key}=" "${STATE_FILE}"; then
        sed -i \
            "s|^${key}=.*|${key}=\"${value}\"|" \
            "${STATE_FILE}";
    else
        printf '%s="%s"\n' \
            "${key}" \
            "${value}" \
            >> "${STATE_FILE}";
    fi
}

stage_mark_done() {
    touch "${STAGE_DIR}/${1}.done";
}

stage_is_done() {
    [[ -f "${STAGE_DIR}/${1}.done" ]];
}

stage_reset() {
    rm -f "${STAGE_DIR}/${1}.done";
}

stage_reset_all() {
    rm -f "${STAGE_DIR}"/*.done;
}

stage_log_path() {
    printf '%s/%s.log\n' \
        "${LOG_DIR}" \
        "${1}";
}