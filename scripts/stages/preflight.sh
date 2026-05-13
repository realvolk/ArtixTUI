#!/usr/bin/env bash
set -Eeuo pipefail;

stage_preflight() {
    if stage_should_skip preflight; then
        return 0;
    fi;

    require_root;
    require_efi;
    require_internet;

    if ! command_exists gum; then
        if [[ -f "/usr/local/bin/gum" ]]; then
            PATH="/usr/local/bin:${PATH}"   
        elif [[ -f "${BASE_DIR}/bin/gum" ]]; then
            log_info "Installing bundled gum binary...";
            install -Dm755 "${BASE_DIR}/bin/gum" /usr/local/bin/gum;
        else
            log_info "Gum not found. Building from source...";

            if ! command_exists go; then
                log_info "Installing Go...";
                pacman -S --noconfirm --needed go;
            fi

            local gum_tmp;
            gum_tmp="$(mktemp -d)";

            git clone --depth 1 \
                https://github.com/charmbracelet/gum.git \
                "${gum_tmp}";

            (
                cd "${gum_tmp}";
                go build -o gum .;
                install -Dm755 gum /usr/local/bin/gum;
            );

            rm -rf "${gum_tmp}";

            log_info "Gum compiled and installed to /usr/local/bin/gum.";
        fi
    fi

    local pkgs=();
    local fs_type;
    fs_type="$(state_get FS_TYPE ext4)";

    command_exists sgdisk       || pkgs+=(gptfdisk);
    command_exists cryptsetup   || pkgs+=(cryptsetup);
    command_exists mkfs.fat     || pkgs+=(dosfstools);
    command_exists lsblk        || pkgs+=(util-linux);
    command_exists wipefs       || pkgs+=(util-linux);
    command_exists btrfs        || pkgs+=(btrfs-progs);

    case "${fs_type}" in
        xfs)
            command_exists mkfs.xfs \
                || pkgs+=(xfsprogs);
            ;;
        f2fs)
            command_exists mkfs.f2fs \
                || pkgs+=(f2fs-tools);
            ;;
        exfat)
            command_exists mkfs.exfat \
                || pkgs+=(exfatprogs);
            ;;
        bcachefs)
            command_exists mkfs.bcachefs \
                || pkgs+=(bcachefs-tools);
            ;;
        zfs)
            command_exists zpool \
                || die 'zfs tools are unavailable in the live environment';
            ;;
    esac

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Installing required tools: ${pkgs[*]}";

        gum spin --spinner dot --title "Preflight – installing dependencies" -- \
            pacman -S --noconfirm --needed "${pkgs[@]}";

        log_info "Preflight dependencies installed.";
    fi;

    stage_mark_done preflight;
}