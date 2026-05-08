#!/usr/bin/env bash
set -Eeuo pipefail;

[[ -f /etc/artix-installer.conf ]] \
    && source /etc/artix-installer.conf

service_exists() {
    local svc="${1}";
    local init="${INIT:-openrc}";

    case "${init}" in
        openrc)
            [[ -f "/etc/init.d/${svc}" ]];
            ;;

        runit)
            [[ -d "/etc/runit/sv/${svc}" ]];
            ;;

        dinit)
            [[ -f "/etc/dinit.d/${svc}" ]];
            ;;

        s6)
            command -v s6-rc &>/dev/null;
            ;;

        *)
            return 1;
            ;;
    esac
}

enable_service() {
    local svc="${1}";
    local init="${INIT:-openrc}";

    service_exists "${svc}" || return 0;

    case "${init}" in
        openrc)
            rc-update add "${svc}" default;
            ;;

        runit)
            ln -sf \
                "/etc/runit/sv/${svc}" \
                "/etc/runit/runsvdir/default/${svc}";
            ;;

        dinit)
            mkdir -p /etc/dinit.d/boot.d;

            ln -sf \
                "../${svc}" \
                "/etc/dinit.d/boot.d/${svc}";
            ;;

        s6)
            s6-rc-bundle-update add default "${svc}" \
                2>/dev/null || true;
            ;;
    esac
}

start_service() {
    local svc="${1}";
    local init="${INIT:-openrc}";

    service_exists "${svc}" || return 0;

    case "${init}" in
        openrc)
            rc-service "${svc}" start;
            ;;

        runit)
            sv up "${svc}" || true;
            ;;

        dinit)
            dinitctl start "${svc}" || true;
            ;;

        s6)
            s6-rc -u change "${svc}" || true;
            ;;
    esac
}