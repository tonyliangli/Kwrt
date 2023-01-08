#!/bin/bash

# SHELL_FOLDER=$(dirname $(readlink -f "$0"))
# bash $SHELL_FOLDER/../common/kernel_5.15.sh

svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/x86/files-5.4 target/linux/x86/files-5.4
rm -rf target/linux/x86/files-5.4/.svn

svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/x86/patches-5.4 target/linux/x86/patches-5.4
rm -rf target/linux/x86/patches-5.4/.svn

sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += autocore-x86 kmod-usb-hid kmod-mmc kmod-sdhci usbutils pciutils lm-sensors-detect kmod-alx kmod-vmxnet3 kmod-igbvf kmod-iavf kmod-bnx2x kmod-pcnet32 kmod-tulip kmod-r8125 kmod-8139cp kmod-8139too kmod-i40e kmod-drm-i915 kmod-drm-amdgpu kmod-mlx4-core kmod-mlx5-core fdisk lsblk kmod-phy-broadcom blkid smartmontools/' target/linux/x86/Makefile
sed -i 's/kmod-igb /kmod-igb-intel /' target/linux/x86/image/64.mk

mv -f tmp/{r81*,igb-intel} feeds/kiddin9/
sed -i 's,kmod-r8169,kmod-r8168,g' target/linux/x86/image/64.mk
sed -i 's/256/1024/g' target/linux/x86/image/Makefile

echo '
CONFIG_CRYPTO_CHACHA20_X86_64=y
CONFIG_CRYPTO_POLY1305_X86_64=y
CONFIG_DRM=y
CONFIG_DRM_I915=y
CONFIG_ACPI=y
CONFIG_X86_ACPI_CPUFREQ=y
CONFIG_NR_CPUS=512
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_SDIO_UART=y
CONFIG_MMC_TEST=y
CONFIG_MMC_DEBUG=y
CONFIG_MMC_SDHCI=y
CONFIG_MMC_SDHCI_ACPI=y
CONFIG_MMC_SDHCI_PCI=y
' >> ./target/linux/x86/config-5.4

sed -i "s/enabled '0'/enabled '1'/g" feeds/packages/utils/irqbalance/files/irqbalance.config

