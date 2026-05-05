#!/usr/bin/env bash
set -o pipefail;

_tui_msg() { dialog --title "${1}" --msgbox "${2}" 8 50; }
_tui_yesno() { dialog --title "${1}" --yesno "${2}" 8 50; }
_tui_menu() { dialog --stdout --title "${1}" --menu "${2}" 15 55 5 "${@:3}"; }

function main {
    [[ ! -t 0 ]] && return 0;

    if [[ -f /var/lib/artix-firstboot-done ]]; then
        [[ "${EUID}" -eq 0 ]] && rm -f /etc/profile.d/firstboot.sh 2>/dev/null;
        return 0;
    fi

    [[ ! -f /usr/local/bin/firstboot.sh ]] && return 0;

    if pgrep -f "[f]irstboot.sh" > /dev/null; then
        return 0;
    fi

    local msg="ARTIX POST-INSTALLATION  \n\nIt looks like this is your first boot.\nThe system is now ready for final setup.\n\nRun setup now?";

    if _tui_yesno "First Boot" "${msg}" 2>/dev/null; then
        clear;
        printf "[*] Launching firstboot script...\n";
        if [[ "${EUID}" -eq 0 ]]; then
            /usr/local/bin/firstboot.sh;
        else
            sudo /usr/local/bin/firstboot.sh;
        fi
        clear;
        return 0;
    else
        clear;
        printf "[*] Skipping setup for now. You can run it manually via /usr/local/bin/firstboot.sh\n";
        sleep 1;
    fi
}

main;