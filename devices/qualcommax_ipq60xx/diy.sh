#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

git_clone_path master https://github.com/coolsnowwolf/lede target/linux/generic/hack-6.1

rm -rf target/linux/qualcommax/!(Makefile) package/kernel/qca-* package/boot/uboot-envtools package/firmware/ipq-wifi
git_clone_path master https://github.com/coolsnowwolf/lede target/linux/qualcommax
git_clone_path master https://github.com/coolsnowwolf/lede package/qca
git_clone_path master https://github.com/coolsnowwolf/lede package/boot/uboot-envtools
git_clone_path master https://github.com/coolsnowwolf/lede package/firmware/ipq-wifi

rm -rf package/feeds/kiddin9/quectel_Gobinet devices/common/patches/kernel_version.patch devices/common/patches/rootfstargz.patch target/linux/generic/hack-6.1/{410-block-fit-partition-parser.patch,724-net-phy-aquantia*,720-net-phy-add-aqr-phys.patch}

curl -sfL https://raw.githubusercontent.com/coolsnowwolf/lede/master/target/linux/generic/pending-6.1/613-netfilter_optional_tcp_window_check.patch -o target/linux/generic/pending-6.1/613-netfilter_optional_tcp_window_check.patch




