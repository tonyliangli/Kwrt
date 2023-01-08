#!/bin/bash
#=================================================
shopt -s extglob

# sed -i "9c LINUX_VERSION-5.4 = .179" include/kernel-version.mk
# sed -i "11c LINUX_KERNEL_HASH-5.4.179 = 2c9bdec0922a95aff34e8d53d2e0ecf7e842033cd908d2959a43d34afb5d897d" include/kernel-version.mk

[ ! -f feeds.conf ] && {
sed -i '$a src-git kiddin9 https://github.com/tonyliangli/openwrt-packages;master' feeds.conf.default
}

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i '/	refresh_config();/d' scripts/feeds

rm -rf package/{base-files,network/config/firewall,network/services/dnsmasq,network/services/ppp,system/opkg,libs/mbedtls}

./scripts/feeds update -a
rm -rf feeds/packages/lang/golang; svn export https://github.com/openwrt/packages/trunk/lang/golang feeds/packages/lang/golang
cp -f feeds/kiddin9/my-default-settings/files/etc/nginx/uci.conf.template feeds/packages/net/nginx-util/files/uci.conf.template && cp -f feeds/kiddin9/my-default-settings/files/etc/config/nginx feeds/packages/net/nginx-util/files/nginx.config
./scripts/feeds update -i
./scripts/feeds install -a -p kiddin9 -f
./scripts/feeds install -a

echo "$(date +"%s")" >version.date
sed -i '/$(curdir)\/compile:/c\$(curdir)/compile: package/opkg/host/compile' package/Makefile
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-advanced luci-app-firewall luci-app-gpsysupgrade luci-app-opkg luci-app-upnp luci-app-autoreboot \
luci-app-wizard luci-base luci-compat luci-lib-ipkg luci-lib-fs \
coremark wget-ssl curl htop nano zram-swap kmod-lib-zstd kmod-tcp-bbr bash openssh-sftp-server block-mount resolveip kmod-ip6-tunnel ds-lite /" include/target.mk
# sed -i "s/procd-ujail//" include/target.mk
sed -i "1181c \ \ DEPENDS:=@PCI_SUPPORT +kmod-ptp" package/kernel/linux/modules/netdevices.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/tonyliangli/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
while [ "$status" == "in_progress" ];do
	sleep 5
	status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/tonyliangli/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
done

mv -f feeds/kiddin9/{r81*,igb-intel} tmp/

sed -i "s/192.168.1/10.10.10/" package/feeds/kiddin9/base-files/files/bin/config_generate
sed -i "s/192.168.1/10.0.0/" package/base-files/files/bin/config_generate
sed -i "110s/127.0.0.1:/127.0.0.1#/" package/feeds/kiddin9/luci-app-bypass/luasrc/controller/bypass.lua
sed -i "22s/127.0.0.1:/127.0.0.1#/; 26s/127.0.0.1:/127.0.0.1#/" package/feeds/kiddin9/luci-app-bypass/root/usr/share/bypass/by-switch
sed -i "s/(CpuMark/\\\ (CpuMark/" package/feeds/kiddin9/my-default-settings/files/sbin/coremark
mv package/feeds/kiddin9/my-default-settings/files/sbin/coremark package/feeds/kiddin9/my-default-settings/files/sbin/cpumark
rm -f package/feeds/packages/libpfring; svn export https://github.com/openwrt/packages/trunk/libs/libpfring package/feeds/kiddin9/libpfring
rm -f package/feeds/packages/xtables-addons; svn export https://github.com/openwrt/packages/trunk/net/xtables-addons package/feeds/kiddin9/xtables-addons
svn export --force https://github.com/tonyliangli/luci-app-ikoolproxy/trunk/root/usr/share/koolproxy/data/source.list package/feeds/kiddin9/luci-app-ikoolproxy/root/usr/share/koolproxy/data/source.list
svn export --force https://github.com/tonyliangli/luci-app-ikoolproxy/trunk/root/usr/share/koolproxy/kpupdate package/feeds/kiddin9/luci-app-ikoolproxy/root/usr/share/koolproxy/kpupdate; chmod 755 package/feeds/kiddin9/luci-app-ikoolproxy/root/usr/share/koolproxy/kpupdate
svn export --force https://github.com/tonyliangli/luci-app-ikoolproxy/trunk/root/etc/init.d/koolproxy package/feeds/kiddin9/luci-app-ikoolproxy/root/etc/init.d/koolproxy; chmod 755 package/feeds/kiddin9/luci-app-ikoolproxy/root/etc/init.d/koolproxy
svn export --force https://github.com/tonyliangli/luci-app-ikoolproxy/trunk/koolproxy/files/x86_64 package/feeds/kiddin9/luci-app-ikoolproxy/koolproxy/files/x86_64; chmod 755 package/feeds/kiddin9/luci-app-ikoolproxy/koolproxy/files/x86_64

(
svn export --force https://github.com/coolsnowwolf/lede/trunk/tools/upx tools/upx
svn export --force https://github.com/coolsnowwolf/lede/trunk/tools/ucl tools/ucl
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic/files-5.4 target/linux/generic/files-5.4
svn co https://github.com/coolsnowwolf/lede/trunk/target/linux/generic/hack-5.4 target/linux/generic/hack-5.4
rm -rf target/linux/generic/hack-5.4/{220-arm-gc_sections*,781-dsa-register*,780-drivers-net*}
) &

sed -i 's?zstd$?zstd ucl upx\n$(curdir)/upx/compile := $(curdir)/ucl/compile?g' tools/Makefile
# sed -i "/BuildPackage,miniupnpd-iptables/d" feeds/packages/net/miniupnpd/Makefile
sed -i 's/\/cgi-bin\/\(luci\|cgi-\)/\/\1/g' `find package/feeds/kiddin9/luci-*/ -name "*.lua" -or -name "*.htm*" -or -name "*.js"` &
sed -i 's/Os/O2/g' include/target.mk
sed -i 's/$(TARGET_DIR)) install/$(TARGET_DIR)) install --force-overwrite --force-depends/' package/Makefile
sed -i "/mediaurlbase/d" package/feeds/*/luci-theme*/root/etc/uci-defaults/*
sed -i 's/=bbr/=cubic/' package/kernel/linux/files/sysctl-tcp-bbr.conf

# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
# rm -rf ./feeds/packages/lang/{golang,node}
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab

sed -i '$a CONFIG_ACPI=y\nCONFIG_X86_ACPI_CPUFREQ=y\nCONFIG_NR_CPUS=128\nCONFIG_FAT_DEFAULT_IOCHARSET="utf8"\nCONFIG_CRYPTO_CHACHA20_NEON=y\n \
CONFIG_CRYPTO_CHACHA20POLY1305=y\nCONFIG_BINFMT_MISC=y' `find target/linux -path "target/linux/*/config-*"`
sh -c "curl -sfL https://github.com/openwrt/openwrt/commit/2e6d19ee32399e37c7545aefc57d41541a406d55.patch | patch -d './' -p1 --forward" || true

sed -i '$a  \
CONFIG_CPU_FREQ_GOV_POWERSAVE=y \
CONFIG_CPU_FREQ_GOV_USERSPACE=y \
CONFIG_CPU_FREQ_GOV_ONDEMAND=y \
CONFIG_CPU_FREQ_GOV_CONSERVATIVE=y \
CONFIG_CRYPTO_CHACHA20_NEON=y \
CONFIG_CRYPTO_CHACHA20POLY1305=y \
CONFIG_FAT_DEFAULT_IOCHARSET="utf8" \
' `find target/linux -path "target/linux/*/config-*"`

date=`date +%m.%d.%Y`
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk

sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/kiddin9/*/Makefile

(
if [ -f sdk.tar.xz ]; then
	sed -i 's,$(STAGING_DIR_HOST)/bin/upx,upx,' package/feeds/kiddin9/*/Makefile
	mkdir sdk
	tar -xJf sdk.tar.xz -C sdk
	cp -rf sdk/*/staging_dir/* ./staging_dir/
	rm -rf sdk.tar.xz sdk
	sed -i '/\(tools\|toolchain\)\/Makefile/d' Makefile
	if [ -f /usr/bin/python ]; then
		ln -sf /usr/bin/python staging_dir/host/bin/python
	else
		ln -sf /usr/bin/python3 staging_dir/host/bin/python
	fi
	ln -sf /usr/bin/python3 staging_dir/host/bin/python3
fi
) &
