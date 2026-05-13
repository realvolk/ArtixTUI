#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/tmp/artix-installer/install.log"
CHROOT_LOG="/mnt/var/log/artix-installer.log"

_ensure_log_dirs() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    [[ -d /mnt ]] && mkdir -p "$(dirname "${CHROOT_LOG}")" || true
}

log_info() {
    local msg="${1}"
    _ensure_log_dirs
    printf '\e[1;34m[*] %s\e[0m\n' "${msg}" | tee -a "${LOG_FILE}" >&2
    [[ -d /mnt ]] && printf '[*] %s\n' "${msg}" >> "${CHROOT_LOG}" 2>/dev/null || true
}

log_warn() {
    local msg="${1}"
    _ensure_log_dirs
    printf '\e[1;33m[!] %s\e[0m\n' "${msg}" | tee -a "${LOG_FILE}" >&2
    [[ -d /mnt ]] && printf '[!] %s\n' "${msg}" >> "${CHROOT_LOG}" 2>/dev/null || true
}

log_error() {
    local msg="${1}"
    _ensure_log_dirs
    printf '\e[1;31m[✗] %s\e[0m\n' "${msg}" | tee -a "${LOG_FILE}" >&2
}

tui_msg() {
    local title="${1}" msg="${2}"
    gum style --bold --foreground 212 "── ${title} ──"
    gum format "${msg}"
    gum confirm "Press Enter to continue" --affirmative="OK" --timeout=0 2>/dev/null || true
}

tui_yesno() {
    local title="${1}" msg="${2}"
    gum style --bold --foreground 212 "── ${title} ──"
    gum format "${msg}"
    gum confirm
}

tui_input() {
    local title="${1}" msg="${2}" default="${3:-}"
    gum style --bold --foreground 212 "── ${title} ──"
    [[ -n "${msg}" ]] && gum format "${msg}"
    gum input --placeholder "${default}" --prompt "> "
}

tui_password() {
    local title="${1}" msg="${2}"
    gum style --bold --foreground 212 "── ${title} ──"
    [[ -n "${msg}" ]] && gum format "${msg}"
    gum input --password --prompt "> "
}

tui_password_confirm() {
    local title="${1:-Password}" prompt="${2:-Enter password:}" confirm_prompt="${3:-Confirm password:}"
    local pass confirm
    while true; do
        gum style --bold --foreground 212 "── ${title} ──"
        pass=$(gum input --password --prompt "${prompt}: ")
        [[ -n "${pass}" ]] || return 1
        confirm=$(gum input --password --prompt "${confirm_prompt}: ")
        [[ -n "${confirm}" ]] || return 1
        if [[ "${pass}" == "${confirm}" ]]; then
            printf '%s\n' "${pass}"
            return 0
        fi
        tui_msg "Mismatch" "Passwords do not match. Try again."
    done
}

tui_menu() {
    local title="${1}" msg="${2}"
    shift 2
    gum style --bold --foreground 212 "── ${title} ──"
    [[ -n "${msg}" ]] && gum format "${msg}"
    gum choose --height=15 "$@"
}

tui_menu_custom() {
    local title="${1}" msg="${2}"
    local height="${3:-15}"
    shift 3
    gum style --bold --foreground 212 "── ${title} ──"
    [[ -n "${msg}" ]] && gum format "${msg}"
    gum choose --height="${height}" "$@"
}

tui_checklist() {
    local title="${1}" msg="${2}"
    shift 2
    gum style --bold --foreground 212 "── ${title} ──"
    [[ -n "${msg}" ]] && gum format "${msg}"
    gum choose --no-limit --height=15 "$@"
}

tui_radiolist() {
    tui_menu "$@"
}

tui_spin() {
    local title="${1}" cmd="${2}"
    gum spin --spinner dot --title "${title}" -- bash -c "${cmd}" 2>&1 | while IFS= read -r line; do log_info "${line}"; done
}

tui_show_file() {
    local title="${1}" file="${2}"
    gum style --bold --foreground 212 "── ${title} ──"
    gum pager < "${file}"
}