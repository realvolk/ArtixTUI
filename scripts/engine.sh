#!/usr/bin/env bash
set -eo pipefail;

_setup_storage() {
    {
        printf "[*] Preparing storage on %s...\n" "${DISK}";
        swapoff -a || true;
        umount -l /mnt 2>/dev/null || true;
        [[ -f /dev/mapper/cryptroot ]] && cryptsetup close cryptroot 2>/dev/null || true;

        printf "[*] Wiping disk signatures...\n";
        wipefs --all --force "${DISK}" &>/dev/null;
        sgdisk --zap-all "${DISK}" &>/dev/null;
        
        printf "[*] Creating partitions...\n";
        sgdisk -n 1:0:+2048M -t 1:ef00 "${DISK}" &>/dev/null;
        sgdisk -n 2:0:0      -t 2:8300 "${DISK}" &>/dev/null;
        udevadm settle && sleep 2;

        local efi_p root_p target_dev;
        efi_p=$(_get_partition_name "${DISK}" 1);
        root_p=$(_get_partition_name "${DISK}" 2);
        target_dev="${root_p}";

        if [[ "${USE_LUKS}" == "yes" ]]; then
            printf "[*] Formatting LUKS container...\n";
            printf "%s" "${LUKS_PASS}" | cryptsetup luksFormat -q --batch-mode "${root_p}" -;
            printf "%s" "${LUKS_PASS}" | cryptsetup open "${root_p}" cryptroot -;
            target_dev="/dev/mapper/cryptroot";
        fi

        if [[ "${FS_TYPE}" == "btrfs" ]]; then
            printf "[*] Creating BTRFS subvolumes...\n";
            mkfs.btrfs -f -q "${target_dev}" &>/dev/null;
            mount "${target_dev}" /mnt;
            for sub in @ @home @log @pkg @snapshots; do
                btrfs subvolume create "/mnt/${sub}" &>/dev/null;
            done
            umount /mnt;
            mount -o "noatime,compress=zstd,subvol=@" "${target_dev}" /mnt;
            mount --mkdir -o "noatime,compress=zstd,subvol=@home" "${target_dev}" /mnt/home;
            mount --mkdir -o "noatime,compress=zstd,subvol=@log" "${target_dev}" /mnt/var/log;
            mount --mkdir -o "noatime,compress=zstd,subvol=@pkg" "${target_dev}" /mnt/var/cache/pacman/pkg;
            mount --mkdir -o "noatime,compress=zstd,subvol=@snapshots" "${target_dev}" /mnt/.snapshots;
        else
            printf "[*] Creating EXT4 filesystem...\n";
            mkfs.ext4 -F -q "${target_dev}" &>/dev/null;
            mount "${target_dev}" /mnt;
        fi

        printf "[*] Formatting EFI partition...\n";
        mkfs.fat -F32 "${efi_p}" &>/dev/null;
        [[ "${BOOTLOADER}" == "efistub" ]] && mount --mkdir "${efi_p}" /mnt/boot || mount --mkdir "${efi_p}" /mnt/boot/efi;
        
        printf "\n[✓] Storage setup complete. Starting installation...\n";
        sleep 2;
    } 2>&1 | dialog --title " Storage Setup " --programbox 20 85
}

_setup_bootloader() {
    _load_state;
    local log_boot="/tmp/bootloader.log";

    {
        local root_dev real_dev uuid hooks cmdline_opts ucode
        ucode=$(_get_cpu_ucode)
    
        if [[ "${USE_LUKS}" == "yes" ]]; then
            real_dev=$(_get_partition_name "${DISK}" 2)
            uuid=$(blkid -s UUID -o value "${real_dev}" | head -n 1)
            cmdline_opts="cryptdevice=UUID=${uuid}:cryptroot root=/dev/mapper/cryptroot rw"
        else
            read -r root_dev < <(findmnt -no SOURCE /mnt)
            uuid=$(blkid -s UUID -o value "${root_dev}" | head -n 1)
            cmdline_opts="root=UUID=${uuid} rw"
        fi

        [[ "${FS_TYPE}" == "btrfs" ]] && cmdline_opts="${cmdline_opts} rootflags=subvol=@"

        hooks="base udev autodetect modconf block"
        [[ "${USE_LUKS}" == "yes" ]] && hooks="${hooks} encrypt"
        [[ "${FS_TYPE}" == "btrfs" ]] && hooks="${hooks} btrfs"
        hooks="${hooks} filesystems keyboard fsck"

        printf "[*] Configuring initramfs and bootloader...\n"
        artix-chroot /mnt /bin/bash <<EOF
set -e
sed -i "s/^HOOKS=(.*/HOOKS=(${hooks})/" /etc/mkinitcpio.conf
mkinitcpio -P &>/dev/null

if [[ "${BOOTLOADER}" == "grub" ]]; then
    pacman -S --noconfirm grub os-prober &>/dev/null
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
    [[ "${USE_LUKS}" == "yes" ]] && echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"${cmdline_opts} |" /etc/default/grub
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARTIX --recheck &>/dev/null
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
elif [[ "${BOOTLOADER}" == "refind" ]]; then
    pacman -S --noconfirm refind &>/dev/null
    refind-install &>/dev/null
    printf "\"Boot Artix\" \"${cmdline_opts} initrd=/boot/${ucode}.img initrd=/boot/initramfs-linux.img\"\n" > /boot/refind_linux.conf
elif [[ "${BOOTLOADER}" == "efistub" ]]; then
    efibootmgr --create --disk "${DISK}" --part 1 --label "Artix Linux" --loader /vmlinuz-linux --unicode "${cmdline_opts} initrd=\\${ucode}.img initrd=\\initramfs-linux.img" --verbose &>/dev/null
fi
EOF
        printf "\n[✓] Bootloader configured successfully.\n"
    } > "${log_boot}" 2>&1

    dialog --title " Bootloader Setup " --textbox "${log_boot}" 20 85
}
