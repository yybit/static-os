#! /bin/bash

set -x

rootfs="$1"
image_name="$2"
arch="${3:-x86_64}"
bios="${4:-uefi}"

if [ "$bios" = "uefi" ]; then
    umount /mnt/example/efi
fi
umount /mnt/example

set -ue 

if [ "$bios" = "legacy" ]; then
    apt remove -y grub-efi && apt autoremove -y && apt install -y grub-pc
fi

touch $image_name
dd if=/dev/null of=$image_name bs=1M seek=768

parted --script $image_name mklabel gpt
if [ "$bios" = "uefi" ]; then
    parted --script $image_name mkpart ESP fat32 1M 65M
    parted --script $image_name set 1 boot on
    parted --script $image_name mkpart primary ext4 65M 449M
    parted --script $image_name mkpart primary ext4 449M 768M
else
    parted --script $image_name mkpart primary 1M 2M
    parted --script $image_name set 1 bios_grub on
    parted --script $image_name mkpart primary ext4 2M 386M
    parted --script $image_name mkpart primary ext4 386M 768M
fi

device_name=`kpartx -a -v $image_name | awk 'NR==1 {print substr($3, 1, length($3)-2)}'`
rootfs_device_name="$device_name"p2
var_device_name="$device_name"p3
mkfs.ext4 /dev/mapper/$rootfs_device_name
mkfs.ext4 /dev/mapper/$var_device_name
mkdir /mnt/example
mount /dev/mapper/$rootfs_device_name /mnt/example/

if [ "$bios" = "uefi" ]; then
    efi_device_name="$device_name"p1
    mkfs.fat -F 32 /dev/mapper/$efi_device_name
    mkdir -p /mnt/example/efi
    mount /dev/mapper/$efi_device_name /mnt/example/efi
fi

cp -a $rootfs/* /mnt/example/

if [ "$bios" = "uefi" ]; then
    mount -t efivarfs efivarfs /sys/firmware/efi/efivars
    grub-install --boot-directory=/mnt/example/boot --target=${arch}-efi --efi-directory=/mnt/example/efi --bootloader-id=static-os --removable
else
    grub-install /dev/${device_name} --boot-directory=/mnt/example/boot
fi

sync
if [ "$bios" = "uefi" ]; then
    umount /mnt/example/efi
fi
umount /mnt/example
kpartx -d /dev/${device_name}
losetup -D