#!/usr/bin/env bash
set -Eeuo pipefail

readonly STATE_ROOT="/tmp/artix-installer"
readonly STATE_FILE="${STATE_ROOT}/state.conf"
readonly STAGE_DIR="${STATE_ROOT}/stages"
readonly LOG_DIR="${STATE_ROOT}/logs"

ensure_state_dirs() {
    mkdir -p "${STATE_ROOT}" "${STAGE_DIR}" "${LOG_DIR}"
}

state_save() {
    ensure_state_dirs
    {
        printf 'DISK=%q\n'                  "${DISK:-}"
        printf 'FS_TYPE=%q\n'               "${FS_TYPE:-}"
        printf 'INIT=%q\n'                  "${INIT:-}"
        printf 'USE_LUKS=%q\n'              "${USE_LUKS:-}"
        printf 'LUKS_PASS=%q\n'             "${LUKS_PASS:-}"
        printf 'BOOTLOADER=%q\n'            "${BOOTLOADER:-}"
        printf 'DISPLAY_MANAGER=%q\n'       "${DISPLAY_MANAGER:-none}"
        printf 'AUDIO_STACK=%q\n'           "${AUDIO_STACK:-pipewire}"
        printf 'SWAP_ENABLED=%q\n'          "${SWAP_ENABLED:-no}"
        printf 'SWAP_SIZE=%q\n'             "${SWAP_SIZE:-0}"
        printf 'EXTRAS=%q\n'                "${EXTRAS:-}"
        printf 'KERNEL_CHOICE=%q\n'         "${KERNEL_CHOICE:-}"
        printf 'KERNEL_IMAGE=%q\n'          "${KERNEL_IMAGE:-}"
        printf 'INITRAMFS_IMAGE=%q\n'       "${INITRAMFS_IMAGE:-}"
        printf 'MICROCODE_IMAGE=%q\n'       "${MICROCODE_IMAGE:-}"
        printf 'MICROCODE_OVERRIDE=%q\n'    "${MICROCODE_OVERRIDE:-auto}"
        printf 'HOSTNAME=%q\n'              "${HOSTNAME:-artix}"
        printf 'TIMEZONE=%q\n'              "${TIMEZONE:-Europe/Belgrade}"
        printf 'LOCALE=%q\n'                "${LOCALE:-en_US.UTF-8}"
        printf 'KEYMAP=%q\n'                "${KEYMAP:-us}"
        printf 'BTRFS_LAYOUT=%q\n'          "${BTRFS_LAYOUT:-standard}"
        printf 'WM_DE=%q\n'                 "${WM_DE:-}"
        printf 'KDE_PROFILE=%q\n'           "${KDE_PROFILE:-desktop}"
        printf 'USER_NAME=%q\n'             "${USER_NAME:-}"
        printf 'USER_PASS=%q\n'             "${USER_PASS:-}"
        printf 'ROOT_PASS=%q\n'             "${ROOT_PASS:-}"
        printf 'USER_SHELL=%q\n'            "${USER_SHELL:-/bin/bash}"
        printf 'NETWORK_STACK=%q\n'         "${NETWORK_STACK:-dhcpcd+iwd}"
        printf 'ALLOW_OFFLINE=%q\n'         "${ALLOW_OFFLINE:-no}"
        printf 'X_STACK=%q\n'               "${X_STACK:-xorg}"
        printf 'ENABLE_ARCH_REPOS=%q\n'     "${ENABLE_ARCH_REPOS:-no}"
    } > "${STATE_FILE}"
    chmod 600 "${STATE_FILE}"
}

state_load() {
    [[ -f "${STATE_FILE}" ]] || return 0
    source "${STATE_FILE}"
}

state_get() {
    local key="${1}"
    local default="${2:-}"
    printf '%s\n' "${!key:-${default}}"
}

state_set() {
    ensure_state_dirs
    local key="${1}"
    local value="${2}"
    export "${key}=${value}"
    local tmpfile="${STATE_FILE}.tmp.$$"
    if [[ -f "${STATE_FILE}" ]]; then
        while IFS= read -r line; do
            if [[ "${line}" =~ ^${key}= ]]; then
                printf '%s=%q\n' "${key}" "${value}" >> "${tmpfile}"
            else
                printf '%s\n' "${line}" >> "${tmpfile}"
            fi
        done < "${STATE_FILE}"
    else
        : > "${tmpfile}"
    fi
    if ! grep -qE "^${key}=" "${STATE_FILE}" 2>/dev/null; then
        printf '%s=%q\n' "${key}" "${value}" >> "${tmpfile}"
    fi
    mv "${tmpfile}" "${STATE_FILE}"
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
            [[ -b "$(state_get DISK)" ]]
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