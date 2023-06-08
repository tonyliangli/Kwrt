#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

rm -rf target/linux/generic target/linux/bcm53xx feeds/routing/batman-adv

svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic target/linux/generic
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/bcm53xx target/linux/bcm53xx

curl -sfL https://raw.githubusercontent.com/coolsnowwolf/lede/master/include/kernel-5.10 -o include/kernel-5.10

svn co https://github.com/openwrt/routing/branches/openwrt-22.03/batman-adv feeds/routing/batman-adv

sed -i "s/=5.4/=5.10/" target/linux/bcm53xx/Makefile

sed -i "s/^TARGET_DEVICES /# TARGET_DEVICES /" target/linux/bcm53xx/image/Makefile
sed -i "s/# TARGET_DEVICES += phicomm_k3/TARGET_DEVICES += phicomm_k3/" target/linux/bcm53xx/image/Makefile
sed -i "s/# TARGET_DEVICES += asus_rt-ac88u/TARGET_DEVICES += asus_rt-ac88u/" target/linux/bcm53xx/image/Makefile
sed -i "s/# TARGET_DEVICES += dlink_dir-885l/TARGET_DEVICES += dlink_dir-885l/" target/linux/bcm53xx/image/Makefile
#sed -i "s/DEVICE_PACKAGES := \$(BRCMFMAC_4366C0) \$(USB3_PACKAGES)/DEVICE_PACKAGES := \$(IEEE8021X) kmod-brcmfmac k3wifi \$(USB3_PACKAGES) k3screenctrl wireless-tools/" target/linux/bcm53xx/image/Makefile