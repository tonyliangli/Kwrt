#!/bin/bash

shopt -s extglob
SHELL_FOLDER=$(dirname $(readlink -f "$0"))

bash $SHELL_FOLDER/../common/kernel_6.6.sh

sed -i "s/-stock//g" package/boot/uboot-envtools/files/mediatek_filogic
sed -i "s/-stock//g" target/linux/mediatek/filogic/base-files/etc/board.d/01_leds
sed -i "s/-stock//g" target/linux/mediatek/filogic/base-files/etc/board.d/02_network
sed -i "s/-stock//g" target/linux/mediatek/filogic/base-files/lib/upgrade/platform.sh
sed -i "s/-stock//g" target/linux/mediatek/base-files/lib/preinit/05_set_preinit_iface

