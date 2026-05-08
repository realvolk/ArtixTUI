#!/usr/bin/env bash
set -Eeuo pipefail;

stage_storage() {
    if stage_is_done storage; then
        printf '[*] Storage stage already completed. Skipping...\n';
        return 0;
    fi;

    partition_disk;
    create_filesystems;
    mount_filesystems;

    stage_mark_done storage;
}