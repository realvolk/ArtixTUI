#!/usr/bin/env bash
set -Eeuo pipefail;

stage_storage() {
    if stage_should_skip storage; then
        return 0;
    fi;

    partition_disk;
    create_filesystems;
    mount_filesystems;

    stage_mark_done storage;
}