#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

rm -rf package/feeds/kiddin9/rtl* package/feeds/packages/gptfdisk

sed -i "s/PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=2024-12-06/" package/network/config/netifd/Makefile

rm -rf devices/common/patches/{glinet,fix.patch,iptables.patch,kernel-defaults.patch,targets.patch}

rm -rf toolchain/musl package/utils/e2fsprogs package/libs/libselinux package/feeds/packages/acl package/feeds/luci/ucode-mod-html package/feeds/luci/rpcd-mod-luci

svn co https://github.com/openwrt/openwrt/branches/openwrt-23.05/toolchain/musl toolchain/musl
svn co https://github.com/openwrt/openwrt/branches/openwrt-23.05/package/utils/e2fsprogs package/utils/e2fsprogs
svn co https://github.com/openwrt/openwrt/branches/openwrt-23.05/package/libs/libselinux package/libs/libselinux
svn co https://github.com/openwrt/openwrt/branches/openwrt-23.05/package/utils/ucode package/utils/ucode
#ln -sf $(pwd)/feeds/luci/modules/luci-base package/feeds/kiddin9/
