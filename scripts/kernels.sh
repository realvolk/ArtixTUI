#!/usr/bin/env bash
set -Eeuo pipefail;

detect_kernel_package() {
    local kernel="${1:-linux}";

    KERNEL_PACKAGE='';
    KERNEL_HEADERS='';

    case "${kernel}" in
        linux)
            KERNEL_PACKAGE='linux';
            KERNEL_HEADERS='linux-headers';
            ;;

        linux-lts)
            KERNEL_PACKAGE='linux-lts';
            KERNEL_HEADERS='linux-lts-headers';
            ;;

        linux-hardened)
            KERNEL_PACKAGE='linux-hardened';
            KERNEL_HEADERS='linux-hardened-headers';
            ;;

        linux-zen)
            KERNEL_PACKAGE='linux-zen';
            KERNEL_HEADERS='linux-zen-headers';
            ;;

        linux-libre)
            KERNEL_PACKAGE='linux-libre';
            KERNEL_HEADERS='linux-libre-headers';
            ;;

        linux-cachyos-bore)
            KERNEL_PACKAGE='linux-cachyos-bore';
            KERNEL_HEADERS='linux-cachyos-bore-headers';
            ;;

        linux-bazzite-bin)
            KERNEL_PACKAGE='linux-bazzite-bin';
            KERNEL_HEADERS='linux-bazzite-bin-headers';
            ;;

        xanmod)
            local cpu_level;

            cpu_level=$(
                /lib/ld-linux-x86-64.so.2 --help \
                    | grep -E 'x86-64-v[2-4] \(supported' \
                    | head -n1 \
                    | awk '{print $1}'
            );

            case "${cpu_level}" in
                x86-64-v4)
                    KERNEL_PACKAGE='linux-xanmod-x64v4';
                    ;;

                x86-64-v3)
                    KERNEL_PACKAGE='linux-xanmod-x64v3';
                    ;;

                x86-64-v2)
                    KERNEL_PACKAGE='linux-xanmod-x64v2';
                    ;;

                *)
                    KERNEL_PACKAGE='linux-xanmod';
                    ;;
            esac

            KERNEL_HEADERS="${KERNEL_PACKAGE}-headers";
            ;;

        *)
            die "unsupported kernel: ${kernel}";
            ;;
    esac
}