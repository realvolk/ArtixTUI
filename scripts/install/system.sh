#!/usr/bin/env bash
set -Eeuo pipefail;

configure_system() {
    local hostname;
    local timezone;
    local locale;
    local keymap;

    hostname="$(state_get HOSTNAME artix)";
    timezone="$(state_get TIMEZONE UTC)";
    locale="$(state_get LOCALE en_US.UTF-8)";
    keymap="$(state_get KEYMAP us)";

    [[ -n "${hostname}" ]] \
        || die 'invalid hostname';

    [[ -n "${timezone}" ]] \
        || die 'invalid timezone';

    [[ -n "${locale}" ]] \
        || die 'invalid locale';

    [[ -n "${keymap}" ]] \
        || die 'invalid keymap';

    {
        printf '[*] Configuring hostname...\n';

        printf '%s\n' "${hostname}" \
            > /mnt/etc/hostname;

        cat <<EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${hostname}.localdomain ${hostname}
EOF

        printf '[*] Configuring locale...\n';

        if grep -q "^#${locale}" /mnt/etc/locale.gen; then
            sed -i \
                "s/^#${locale}/${locale}/" \
                /mnt/etc/locale.gen;
        elif ! grep -q "^${locale}" /mnt/etc/locale.gen; then
            printf '%s UTF-8\n' "${locale%% *}" \
                >> /mnt/etc/locale.gen;
        fi

        if ! artix-chroot /mnt locale-gen; then
            die 'failed to generate locale';
        fi

        cat <<EOF > /mnt/etc/locale.conf
LANG=${locale}
EOF

        printf '[*] Configuring keyboard layout...\n';

        cat <<EOF > /mnt/etc/vconsole.conf
KEYMAP=${keymap}
EOF

        printf '[*] Configuring timezone...\n';

        [[ -e "/mnt/usr/share/zoneinfo/${timezone}" ]] \
            || die 'invalid timezone path';

        ln -sf \
            "/usr/share/zoneinfo/${timezone}" \
            /mnt/etc/localtime;

        if ! artix-chroot /mnt hwclock --systohc; then
            die 'failed to synchronize hardware clock';
        fi

        printf '\n[*] System configuration complete.\n';
    } 2>&1 | dialog \
        --clear \
        --title " System Configuration " \
        --programbox 20 85;
}