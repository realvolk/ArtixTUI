#!/usr/bin/env bash
set -Eeuo pipefail;

readonly STATE_ROOT="/tmp/artix-installer";
readonly STATE_FILE="${STATE_ROOT}/state.conf";

readonly STAGE_DIR="${STATE_ROOT}/stages";
readonly LOG_DIR="${STATE_ROOT}/logs";

ensure_state_dirs() {
    mkdir -p \
        "${STATE_ROOT}" \
        "${STAGE_DIR}" \
        "${LOG_DIR}";
}

state_save() {
    ensure_state_dirs;

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
    ensure_state_dirs;

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
    ensure_state_dirs;

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
    ensure_state_dirs;

    printf '%s/%s.log\n' \
        "${LOG_DIR}" \
        "${1}";
}

stage_require_mount() {
    mountpoint -q /mnt
}

stage_require_storage() {
    stage_require_mount \
        && [[ -d /mnt/etc ]] \
        && (
            mountpoint -q /mnt/boot \
            || mountpoint -q /mnt/efi \
            || [[ -f /mnt/etc/fstab ]]
        )
}

stage_require_chroot() {
    stage_require_storage \
        && [[ -x /mnt/usr/bin/bash ]] \
        && [[ -f /mnt/etc/fstab ]]
}

stage_require_post() {
    stage_require_chroot \
        && [[ -d /mnt/home || -d /mnt/root ]]
}

stage_validate() {
    local stage="${1}";

    case "${stage}" in
        preflight)
            return 0
            ;;

        storage)
            stage_require_mount
            ;;

        base)
            [[ -x /mnt/usr/bin/bash ]]
            ;;

        chroot)
            [[ -f /mnt/etc/fstab ]]
            ;;

        post)
            [[ -d /mnt/home || -d /mnt/root ]]
            ;;

        finalize)
            return 0
            ;;

        *)
            return 1
            ;;
    esac
}

stage_reset_from() {
    local stage="${1}";
    local reset='false';
    local current;

    for current in \
        preflight \
        storage \
        base \
        chroot \
        post \
        finalize; do

        if [[ "${current}" == "${stage}" ]]; then
            reset='true';
        fi

        if [[ "${reset}" == 'true' ]]; then
            stage_reset "${current}";
        fi
    done
}

stage_should_skip() {
    local stage="${1}";

    if ! stage_is_done "${stage}"; then
        return 1;
    fi

    if ! stage_validate "${stage}"; then
        printf '[!] Stage "%s" marked complete but environment is invalid.\n' \
            "${stage}";

        printf '[!] Resetting stage state...\n';

        stage_reset_from "${stage}";

        return 1;
    fi

    printf '[*] %s stage already completed. Skipping...\n' \
        "${stage^}";

    return 0;
}