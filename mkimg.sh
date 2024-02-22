#! /bin/bash

set -x

rootfs="$1"
image_name="$2"

# umount /mnt/example/efi
umount /mnt/example

set -ue 

touch $image_name
dd if=/dev/null of=$image_name bs=1M seek=768

parted --script $image_name mklabel gpt
parted --script $image_name mkpart primary 1M 2M
# parted --script $image_name mkpart ESP fat32 2M 18M
# parted --script $image_name set 1 boot on
parted --script $image_name set 1 bios_grub on

# Rootfs A, 256M
parted --script $image_name mkpart primary ext4 2M 386M
# /var
parted --script $image_name mkpart primary ext4 386M 768M

device_name=`kpartx -a -v $image_name | awk 'NR==1 {print substr($3, 1, length($3)-2)}'`
# efi_device_name="$device_name"p2
rootfs_device_name="$device_name"p2
var_device_name="$device_name"p3
# mkfs.fat -F 32 /dev/mapper/$efi_device_name
mkfs.ext4 /dev/mapper/$rootfs_device_name
mkfs.ext4 /dev/mapper/$var_device_name

mkdir /mnt/example
mount /dev/mapper/$rootfs_device_name /mnt/example/
# mkdir -p /mnt/example/efi
# mount /dev/mapper/$efi_device_name /mnt/example/efi

cp -a $rootfs/* /mnt/example/

# grub-install --boot-directory=/mnt/example/boot --target=x86_64-efi --efi-directory=/mnt/example/efi --bootloader-id=staticos
grub-install /dev/${device_name} --boot-directory=/mnt/example/boot

sync
# umount /mnt/example/efi
umount /mnt/example
kpartx -d /dev/${device_name}
losetup -D