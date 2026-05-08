#!/usr/bin/env bash
set -Eeuo pipefail;

stage_base() {
    if stage_is_done base; then
        printf '[*] Base stage already completed. Skipping...\n';
        return 0;
    fi;

    install_base_system;

    stage_mark_done base;
}