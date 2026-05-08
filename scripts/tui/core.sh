#!/usr/bin/env bash
set -Eeuo pipefail;

tui_msg() {
    local title="${1}";
    local message="${2}";

    dialog \
        --clear \
        --title " ${title} " \
        --msgbox "${message}" \
        10 60;
}

tui_yesno() {
    local title="${1}";
    local message="${2}";

    dialog \
        --clear \
        --title " ${title} " \
        --yesno "${message}" \
        10 60;
}

tui_input() {
    local title="${1}";
    local message="${2}";
    local default="${3:-}";

    dialog --stdout \
        --clear \
        --title " ${title} " \
        --inputbox "${message}" \
        10 60 \
        "${default}";
}

tui_password() {
    local title="${1}";
    local message="${2}";

    dialog --stdout \
        --clear \
        --insecure \
        --title " ${title} " \
        --passwordbox "${message}" \
        10 60;
}

tui_menu() {
    local title="${1}";
    local message="${2}";
    shift 2;

    dialog --stdout \
        --clear \
        --title " ${title} " \
        --menu "${message}" \
        16 60 8 \
        "$@";
}

tui_checklist() {
    local title="${1}";
    local message="${2}";
    shift 2;

    dialog --stdout \
        --clear \
        --separate-output \
        --title " ${title} " \
        --checklist "${message}" \
        18 70 10 \
        "$@";
}

tui_radiolist() {
    local title="${1}";
    local message="${2}";
    shift 2;

    dialog --stdout \
        --clear \
        --radiolist "${message}" \
        18 70 10 \
        "$@";
}

tui_infobox() {
    local title="${1}";
    local message="${2}";

    dialog \
        --clear \
        --title " ${title} " \
        --infobox "${message}" \
        6 50;
}

tui_textbox() {
    local title="${1}";
    local file="${2}";

    dialog \
        --clear \
        --title " ${title} " \
        --textbox "${file}" \
        20 80;
}