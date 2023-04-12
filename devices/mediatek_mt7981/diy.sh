#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

rm -rf package/feeds/kiddin9/rtl*

rm -rf devices/common/patches/{glinet,fix.patch,iptables.patch,kernel-defaults.patch,targets.patch}

rm -rf package/libs/mbedtls/patches/200-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch

rm -rf toolchain/musl

svn co https://github.com/openwrt/openwrt/branches/openwrt-22.03/toolchain/musl toolchain/musl
