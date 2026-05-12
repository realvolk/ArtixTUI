#!/usr/bin/env bash
set -Eeuo pipefail;

configure_users() {
    local username;
    local password;
    local root_password;
    local shell;

    username="$(state_get USER_NAME)";
    password="$(state_get USER_PASS)";
    root_password="$(state_get ROOT_PASS)";
    shell="$(state_get USER_SHELL /bin/bash)";

    [[ "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]] \
        || die 'invalid username';

    case "${shell}" in
        bash) shell="/bin/bash" ;;
        zsh)  shell="/bin/zsh" ;;
        fish) shell="/usr/bin/fish" ;;
    esac

    [[ -x "${shell}" ]] || shell="/bin/bash"

    {
        printf '[*] Configuring users...\n';

        artix-chroot /mnt /bin/bash <<EOF
set -Eeuo pipefail

echo "root:${root_password}" | chpasswd

if ! id "${username}" &>/dev/null; then
    useradd \
        -m \
        -G wheel,audio,video,storage \
        -s "${shell}" \
        "${username}"

    echo "${username}:${password}" | chpasswd
fi

sed -i \
    's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' \
    /etc/sudoers

sed -i \
    's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' \
    /etc/sudoers
EOF

        printf '\n[*] User configuration complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " User Configuration " \
        --programbox 20 85;
}