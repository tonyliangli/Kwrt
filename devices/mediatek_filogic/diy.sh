#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))
bash $SHELL_FOLDER/../common/kernel_5.15.sh

sh -c "curl -sfL https://patch-diff.githubusercontent.com/raw/openwrt/openwrt/pull/11115.patch | patch -d './' -p1 --forward"
sh -c "curl -sfL https://github.com/openwrt/openwrt/commit/8686a9a085d4313a0107a3e4378b3762c8293570.patch | patch -d './' -p1 --forward"