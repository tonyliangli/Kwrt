#!/usr/bin/env bash
set -Eeuo pipefail

KWRT_DIR="${KWRT_DIR:-/Users/litongliang/Repositories/Git/GitHub/Kwrt}"
OP_PACKAGES_DIR="${OP_PACKAGES_DIR:-/Users/litongliang/Repositories/Git/GitHub/op-packages}"
TARGET="${TARGET:-x86_64}"
EVENT_PARAM="${EVENT_PARAM:-}"
IMAGE="${IMAGE:-ubuntu:24.04}"
APT_MIRROR="${APT_MIRROR:-http://mirrors.tuna.tsinghua.edu.cn/ubuntu}"
APT_PORTS_MIRROR="${APT_PORTS_MIRROR:-http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports}"
GO_BOOTSTRAP_VERSION="${GO_BOOTSTRAP_VERSION:-1.24.6}"
OUTPUT_DIR="${OUTPUT_DIR:-$KWRT_DIR/.local-actions/${TARGET}-$(date +%Y%m%d-%H%M%S)}"
CONTAINER_NAME="${CONTAINER_NAME:-kwrt-actions-${TARGET}-$(date +%Y%m%d-%H%M%S)}"
SOURCE_TREE="${SOURCE_TREE:-worktree}"
HOST_UNAME="$(uname -s 2>/dev/null || true)"
HOST_ARCH="$(uname -m 2>/dev/null || true)"
if [ -z "${DOCKER_PLATFORM:-}" ] && [ "$HOST_UNAME" = "Darwin" ] && [ "$HOST_ARCH" = "arm64" ]; then
	DOCKER_PLATFORM="linux/arm64"
else
	DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
fi

if ! command -v docker >/dev/null 2>&1; then
	echo "docker not found" >&2
	exit 1
fi

if [ ! -d "$KWRT_DIR/.github/workflows" ]; then
	echo "KWRT_DIR does not look like the Kwrt repository: $KWRT_DIR" >&2
	exit 1
fi

if [ ! -d "$OP_PACKAGES_DIR/luci-base" ]; then
	echo "OP_PACKAGES_DIR does not look like op-packages: $OP_PACKAGES_DIR" >&2
	exit 1
fi

mkdir -p "$OUTPUT_DIR/logs"

echo "Output: $OUTPUT_DIR"
echo "Container: $CONTAINER_NAME"
echo "Image: $IMAGE ($DOCKER_PLATFORM)"

docker run --rm -i \
	--platform "$DOCKER_PLATFORM" \
	--name "$CONTAINER_NAME" \
	-e TARGET="$TARGET" \
	-e EVENT_PARAM="$EVENT_PARAM" \
	-e TOKEN_KIDDIN9="${TOKEN_KIDDIN9:-}" \
	-e REPO_TOKEN="${REPO_TOKEN:-${TOKEN_KIDDIN9:-}}" \
	-e PPPOE_USERNAME="${PPPOE_USERNAME:-}" \
	-e PPPOE_PASSWD="${PPPOE_PASSWD:-}" \
	-e SCKEY="${SCKEY:-}" \
	-e TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}" \
	-e TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}" \
	-e SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}" \
	-e DOCKER_ID="${DOCKER_ID:-}" \
	-e DOCKER_PASSWD="${DOCKER_PASSWD:-}" \
	-e SOURCE_TREE="$SOURCE_TREE" \
	-e APT_MIRROR="$APT_MIRROR" \
	-e APT_PORTS_MIRROR="$APT_PORTS_MIRROR" \
	-e GO_BOOTSTRAP_VERSION="$GO_BOOTSTRAP_VERSION" \
	-e TZ=Asia/Shanghai \
	-v "$KWRT_DIR:/host/Kwrt:ro" \
	-v "$OP_PACKAGES_DIR:/host/op-packages:ro" \
	-v "$OUTPUT_DIR:/host/output" \
	"$IMAGE" bash -s <<'CONTAINER_SCRIPT'
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
cat >/etc/apt/apt.conf.d/99local-actions-timeouts <<'APT_TIMEOUTS'
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::ftp::Timeout "30";
DPkg::Lock::Timeout "30";
APT_TIMEOUTS
apt_retry() {
	local attempt max_attempts=8
	for attempt in $(seq 1 "$max_attempts"); do
		echo "apt attempt $attempt/$max_attempts: $*"
		if "$@"; then
			return 0
		fi
		apt-get -o Acquire::Retries=5 -qq update || true
		sleep 10
	done
	return 1
}

if [ -n "${APT_MIRROR:-}" ]; then
	sed -i \
		-e "s#http://archive.ubuntu.com/ubuntu#${APT_MIRROR}#g" \
		-e "s#http://security.ubuntu.com/ubuntu#${APT_MIRROR}#g" \
		-e "s#http://ports.ubuntu.com/ubuntu-ports#${APT_PORTS_MIRROR:-$APT_MIRROR}#g" \
		/etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
fi
apt_retry apt-get -o Acquire::Retries=5 -qq update
apt_retry apt-get -o Acquire::Retries=5 -qq install -y --fix-missing sudo ca-certificates git rsync curl jq tzdata >/dev/null

if ! id runner >/dev/null 2>&1; then
	useradd -m -s /bin/bash runner
fi
echo 'runner ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/runner
chmod 0440 /etc/sudoers.d/runner
mkdir -p /home/runner/work/Kwrt /mnt/openwrt /host/output/logs /opt/op-packages
rsync -a --delete --exclude='.git' /host/op-packages/ /opt/op-packages/
chown -R runner:runner /home/runner /mnt/openwrt /host/output /opt/op-packages

cat >/tmp/local-actions-runner.sh <<'RUNNER_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

export GITHUB_WORKSPACE=/home/runner/work/Kwrt/Kwrt
export GITHUB_REPOSITORY=tonyliangli/Kwrt
export GITHUB_ENV=/tmp/github_env
export TARGET="${TARGET:-x86_64}"
export EVENT_ACTION="${TARGET} ${EVENT_PARAM:-}"
export TZ=Asia/Shanghai
: >"$GITHUB_ENV"

exec > >(tee -a /host/output/logs/reproduce.log) 2>&1

step() {
	printf '\n========== %s ==========\n' "$1"
}

append_env() {
	local key="$1" value="$2"
	printf '%s=%s\n' "$key" "$value" >>"$GITHUB_ENV"
	export "$key=$value"
}

contains() {
	case "$1" in
		*"$2"*) return 0 ;;
		*) return 1 ;;
	esac
}

apt_retry() {
	local attempt max_attempts=8
	for attempt in $(seq 1 "$max_attempts"); do
		echo "apt attempt $attempt/$max_attempts: $*"
		if "$@"; then
			return 0
		fi
		sudo -E apt-get -o Acquire::Retries=5 -qq update || true
		sleep 10
	done
	return 1
}

git_clone_path() {
	trap 'rm -rf "$tmpdir"' RETURN
	branch="$1" rurl="$2" mv="${3:-}" && { [ "$mv" = "mv" ] && shift 3 || shift 2; }
	rootdir="$PWD"
	tmpdir="$(mktemp -d)" || exit 1
	if [ ${#branch} -lt 10 ]; then
		git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$rurl" "$tmpdir"
		cd "$tmpdir"
	else
		git clone --filter=blob:none --sparse "$rurl" "$tmpdir"
		cd "$tmpdir"
		git checkout "$branch"
	fi
	if [ "$?" != 0 ]; then
		echo "error on $rurl"
		exit 1
	fi
	git sparse-checkout init --cone
	git sparse-checkout set "$@"
	if [ "$mv" != "mv" ]; then
		cp -rn ./* "$rootdir/" || true
	else
		mv -n "$@"/* "$rootdir/$@/" || true
	fi
	cd "$rootdir"
}
export -f git_clone_path

step "repo-dispatcher.yml / Checkout"
rm -rf "$GITHUB_WORKSPACE"
mkdir -p "$(dirname "$GITHUB_WORKSPACE")"
mkdir -p "$GITHUB_WORKSPACE"
git config --global --add safe.directory /host/Kwrt || true
if [ "${SOURCE_TREE:-tracked}" = "worktree" ]; then
	rsync -a --delete \
		--exclude='.git' \
		--exclude='.local-actions' \
		/host/Kwrt/ "$GITHUB_WORKSPACE/"
elif [ "${SOURCE_TREE:-tracked}" = "head" ] || git -C /host/Kwrt diff --name-only --diff-filter=U | grep -q .; then
	echo "Using a clean export from /host/Kwrt HEAD."
	git -C /host/Kwrt archive HEAD | tar -x -C "$GITHUB_WORKSPACE"
else
	echo "Using /host/Kwrt HEAD plus local changes to tracked files."
	git -C /host/Kwrt archive HEAD | tar -x -C "$GITHUB_WORKSPACE"
	git -C /host/Kwrt ls-files -m -z | while IFS= read -r -d '' path; do
		mkdir -p "$GITHUB_WORKSPACE/$(dirname "$path")"
		cp -a "/host/Kwrt/$path" "$GITHUB_WORKSPACE/$path"
	done
	git -C /host/Kwrt ls-files -d -z | while IFS= read -r -d '' path; do
		rm -f "$GITHUB_WORKSPACE/$path"
	done
fi
cd "$GITHUB_WORKSPACE"
git status --short || true

step "repo-dispatcher.yml / cancel running workflows"
if contains "${EVENT_PARAM:-}" "cw"; then
	echo "Local run: would cancel remote workflows when param contains cw."
else
	echo "Skipped, param does not contain cw."
fi

step "repo-dispatcher.yml / Load Settings.ini"
source "$GITHUB_WORKSPACE/devices/common/settings.ini"
if [ -f "$GITHUB_WORKSPACE/devices/$TARGET/settings.ini" ]; then
	source "$GITHUB_WORKSPACE/devices/$TARGET/settings.ini"
fi
append_env REPO_URL "$REPO_URL"
append_env REPO_BRANCH "${REPO_BRANCH:-}"

step "repo-dispatcher.yml / Trigger Packages Update"
echo "Local run: using writable container copy at /opt/op-packages; remote dispatch is not sent."
git config --global --add safe.directory /host/op-packages || true
git -C /host/op-packages rev-parse --short HEAD || true

step "repo-dispatcher.yml / Trigger Compile"
echo "Local repository_dispatch event_type: $EVENT_ACTION"

step "Openwrt-AutoBuild.yml / Checkout"
cd "$GITHUB_WORKSPACE"
git status --short || true

step "Openwrt-AutoBuild.yml / Load Settings.ini"
echo "$TARGET"
source "$GITHUB_WORKSPACE/devices/common/settings.ini"
if [ -f "$GITHUB_WORKSPACE/devices/$TARGET/settings.ini" ]; then
	source "$GITHUB_WORKSPACE/devices/$TARGET/settings.ini"
fi
append_env REPO_URL "$REPO_URL"
append_env REPO_BRANCH "${REPO_BRANCH:-}"
append_env CONFIG_FILE "$CONFIG_FILE"
append_env DIY_SH "$DIY_SH"
append_env FREE_UP_DISK "$FREE_UP_DISK"
append_env UPLOAD_BIN_DIR_FOR_ARTIFACT "$UPLOAD_BIN_DIR_FOR_ARTIFACT"
append_env UPLOAD_FIRMWARE_FOR_ARTIFACT "$UPLOAD_FIRMWARE_FOR_ARTIFACT"
append_env UPLOAD_FIRMWARE_FOR_RELEASE "$UPLOAD_FIRMWARE_FOR_RELEASE"
append_env UPLOAD_FIRMWARE_TO_COWTRANSFER "$UPLOAD_FIRMWARE_TO_COWTRANSFER"
append_env UPLOAD_FIRMWARE_TO_WETRANSFER "$UPLOAD_FIRMWARE_TO_WETRANSFER"

sed -i "1a REPO_TOKEN=${REPO_TOKEN:-}" "$GITHUB_WORKSPACE/devices/common/diy.sh"
sed -i "1a TARGET=$TARGET" "$GITHUB_WORKSPACE/devices/common/diy.sh"
sed -i 's#src-git kiddin9 https://github.com/tonyliangli/op-packages.git;main#src-link kiddin9 ../local-feeds/kiddin9#' "$GITHUB_WORKSPACE/devices/common/diy.sh"

step "Openwrt-AutoBuild.yml / Trigger Packages Update"
if contains "$EVENT_ACTION" "pkg"; then
	echo "Local run: would trigger op-packages update remotely; using mounted local op-packages instead."
else
	echo "Skipped, event action does not contain pkg."
fi

step "Openwrt-AutoBuild.yml / Free disk space"
df -hT
echo "Local container: external free-disk-space action is represented by this disk report."

step "Openwrt-AutoBuild.yml / Initialization environment"
apt_retry sudo -E apt-get -o Acquire::Retries=5 -qq update
APT_BUILD_PACKAGES=(build-essential clang flex bison g++ gawk gettext git libncurses5-dev libssl-dev
	python3-setuptools rsync swig unzip zlib1g-dev file wget
	llvm python3-pyelftools libpython3-dev aria2 jq qemu-utils ccache rename
	libelf-dev device-tree-compiler libgmp3-dev libmpc-dev libfuse-dev zip)
if [ "$(dpkg --print-architecture)" = "amd64" ]; then
	APT_BUILD_PACKAGES+=(gcc-multilib g++-multilib)
else
	echo "Local arm64 host: skipping gcc-multilib and g++-multilib; OpenWrt target remains $TARGET."
fi
apt_retry sudo -E apt-get -o Acquire::Retries=5 -qq install -y --fix-missing "${APT_BUILD_PACKAGES[@]}"
GO_BOOTSTRAP_ROOT=""
if [ "$(dpkg --print-architecture)" = "arm64" ]; then
	GO_BOOTSTRAP_ROOT="/opt/go-bootstrap"
	GO_BOOTSTRAP_TARBALL="go${GO_BOOTSTRAP_VERSION}.linux-arm64.tar.gz"
	GO_BOOTSTRAP_URL="https://go.dev/dl/${GO_BOOTSTRAP_TARBALL}"
	GO_BOOTSTRAP_FALLBACK_URL="https://dl.google.com/go/${GO_BOOTSTRAP_TARBALL}"
	echo "Installing Go bootstrap ${GO_BOOTSTRAP_VERSION} for arm64 host builds..."
	rm -f "/tmp/${GO_BOOTSTRAP_TARBALL}"
	if ! curl -fL --retry 5 --connect-timeout 20 -o "/tmp/${GO_BOOTSTRAP_TARBALL}" "$GO_BOOTSTRAP_URL"; then
		curl -fL --retry 5 --connect-timeout 20 -o "/tmp/${GO_BOOTSTRAP_TARBALL}" "$GO_BOOTSTRAP_FALLBACK_URL"
	fi
	sudo rm -rf "$GO_BOOTSTRAP_ROOT" /opt/go
	sudo tar -C /opt -xzf "/tmp/${GO_BOOTSTRAP_TARBALL}"
	sudo mv /opt/go "$GO_BOOTSTRAP_ROOT"
	"$GO_BOOTSTRAP_ROOT/bin/go" version
fi
sudo -E apt-get -qq autoremove --purge
sudo -E apt-get -qq clean
sudo timedatectl set-timezone "Asia/Shanghai" || sudo ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --global user.name "github-actions[bot]"

step "Openwrt-AutoBuild.yml / Get current date"
append_env date "$(date +'%m/%d_%Y_%H/%M')"
append_env date2 "$(date +'%m/%d %Y')"
VERSION="$(echo "$EVENT_ACTION" | grep -Eo " [0-9.]+" | sed -e 's/ //')" || true
if [ -n "${VERSION:-}" ]; then
	append_env VERSION "$VERSION"
else
	append_env VERSION "$(date +'%m.%d')"
fi

step "Openwrt-AutoBuild.yml / Clone source code"
set -x
TAG_INFO=""
if [ -n "${TOKEN_KIDDIN9:-}" ]; then
	TAG_INFO="$(curl -gs -H 'Content-Type: application/json' \
		-H "Authorization: Bearer ${TOKEN_KIDDIN9}" \
		-X POST -d '{ "query": "query {repository(owner: \"openwrt\", name: \"openwrt\") {refs(refPrefix: \"refs/tags/\", first: 4, orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {nodes {name target { ... on Tag {tagger {date}}}}}}}"}' https://api.github.com/graphql)" || true
fi
TAG_DATE="$(echo ${TAG_INFO:-} | jq -r '.data.repository.refs.nodes[]? | select(.name | startswith("v25")) | .target.tagger.date' 2>/dev/null | head -n 1)" || true
if [ -n "${TAG_DATE:-}" ] && [[ $(( ($(date +%s) - $(date -d "$TAG_DATE" +%s)) / 86400 )) -lt 10 || "$(contains "$EVENT_ACTION" "tags" && echo true || echo false)" == "true" ]]; then
	REPO_BRANCH="$(echo ${TAG_INFO} | jq -r '.data.repository.refs.nodes[].name' | grep v25 | head -n 1)"
else
	REPO_BRANCH="openwrt-25.12"
fi
echo 'CONFIG_VERSION_REPO="https://dl.openwrt.ai/releases/25.12"' >>devices/common/.config
if [[ ! "${REPO_BRANCH:-}" && "$REPO_URL" == "https://github.com/openwrt/openwrt" ]]; then
	git clone "$REPO_URL" -b "$REPO_BRANCH" openwrt
elif [[ ! "${REPO_BRANCH:-}" ]]; then
	git clone "$REPO_URL" openwrt
else
	if [[ ${#REPO_BRANCH} -lt 10 ]]; then
		git clone "$REPO_URL" -b "$REPO_BRANCH" openwrt
	else
		git clone "$REPO_URL" openwrt
		cd openwrt
		git checkout "$REPO_BRANCH"
		cd "$GITHUB_WORKSPACE"
	fi
fi
set +x

step "Openwrt-AutoBuild.yml / Free up disk space"
sudo mkdir -p -m 777 /mnt/openwrt/build_dir openwrt/staging_dir
ln -sf /mnt/openwrt/build_dir openwrt/build_dir
sudo ln -sf openwrt/staging_dir /mnt/openwrt/staging_dir

step "Openwrt-AutoBuild.yml / Load custom configuration"
cp -rf devices/common/. openwrt/
cp -rf "devices/$TARGET/." openwrt/
cp -rf devices openwrt/
cd openwrt
mkdir -p local-feeds
rsync -a --delete /opt/op-packages/ local-feeds/kiddin9/
chmod +x "devices/common/$DIY_SH"
/bin/bash "devices/common/$DIY_SH"
cp -f "devices/common/$CONFIG_FILE" .config
if [ -f "devices/$TARGET/$CONFIG_FILE" ]; then
	echo >>.config
	cat "devices/$TARGET/$CONFIG_FILE" >>.config
fi
if [ "$(dpkg --print-architecture)" = "arm64" ] && [ -x "${GO_BOOTSTRAP_ROOT:-}/bin/go" ]; then
	sed -i \
		-e '/^CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=/d' \
		-e '/^CONFIG_GOLANG_BUILD_BOOTSTRAP=/d' \
		-e '/^# CONFIG_GOLANG_BUILD_BOOTSTRAP is not set/d' \
		.config
	{
		echo "CONFIG_GOLANG_EXTERNAL_BOOTSTRAP_ROOT=\"${GO_BOOTSTRAP_ROOT}\""
		echo '# CONFIG_GOLANG_BUILD_BOOTSTRAP is not set'
	} >>.config
fi
if [ -f "devices/$TARGET/$DIY_SH" ]; then
	chmod +x "devices/$TARGET/$DIY_SH"
	echo "/bin/bash devices/$TARGET/$DIY_SH"
	/bin/bash "devices/$TARGET/$DIY_SH"
fi
if [ -f "devices/$TARGET/default-settings" ]; then
	echo >>package/*/*/my-default-settings/files/etc/uci-defaults/99-default-settings
	cat "devices/$TARGET/default-settings" >>package/*/*/my-default-settings/files/etc/uci-defaults/99-default-settings
fi
cp -Rf ./diy/* ./ || true

step "Openwrt-AutoBuild.yml / Apply patches"
cp -rn devices/common/patches "devices/$TARGET/"
if [ -n "$(ls -A "devices/$TARGET"/*.bin.patch 2>/dev/null)" ]; then
	git apply "devices/$TARGET"/patches/*.bin.patch
fi
find "devices/$TARGET/patches" -maxdepth 1 -type f -name '*.revert.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "patch -d './' -R --no-backup-if-mismatch -p1 -F 1 --ignore-whitespace -i '%'"
find "devices/$TARGET/patches" -maxdepth 1 -type f -name '*.patch' ! -name '*.revert.patch' ! -name '*.bin.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "patch -d './' --no-backup-if-mismatch -p1 -F 1 --ignore-whitespace -i '%'"

step "Openwrt-AutoBuild.yml / Defconfig"
make defconfig
if [[ ! "$TARGET" =~ (amlogic_meson8b|armsr_armv8|bcm27xx_*|rockchip_armv8|sunxi_*|x86_*|siflower_*) ]]; then
	sed -n '/# Wireless Drivers/,/# end of Wireless Drivers/p' .config | sed -e 's/=m/=n/' >>.config
	sed -i "s/\(kmod-qca.*\)=m/\1=n/" .config
	make defconfig
fi
cat .config >/host/output/logs/final.config
cat .config

step "Openwrt-AutoBuild.yml / Cache"
echo "Local run: cache action is not restored; build_dir and staging_dir are persisted under /host/output."

step "Openwrt-AutoBuild.yml / SSH connection to Actions"
if contains "$EVENT_ACTION" "ssh"; then
	echo "Local run: debugger action skipped."
else
	echo "Skipped, event action does not contain ssh."
fi

step "Openwrt-AutoBuild.yml / Compile the firmware"
df -hT
echo -e "$(($(nproc)+1)) thread compile"
if ! make -j$(($(nproc)+1)); then
	log=/host/output/logs/make-Vs.log
	echo "Parallel make failed; running workflow fallback: make V=s"
	if ! make V=s &>"$log"; then
		echo "make V=s failed; tail follows:"
		tail -200 "$log" || true
		df -hT
		exit 1
	fi
fi
rm -rf staging_dir/toolchain-*/bin/*openwrt-linux-musl-lto-dump
rm -rf staging_dir/toolchain-*/initial
df -hT

step "Openwrt-AutoBuild.yml / Organize files"
cd "$GITHUB_WORKSPACE"
target_dirs=(openwrt/bin/targets/*/*)
if [ ! -d "${target_dirs[0]:-}" ]; then
	echo "No firmware target directory found under openwrt/bin/targets" >&2
	exit 1
fi

for target_dir in "${target_dirs[@]}"; do
	cp "$GITHUB_WORKSPACE/openwrt/.config" "$target_dir/$TARGET.config" || true
	cp "$GITHUB_WORKSPACE"/openwrt/build_dir/target-*/linux-*/linux-*/.config "$target_dir/$TARGET"_kernel.config || true
done

rename -v "s/openwrt-/${VERSION}-openwrt-/" ./firmware/*/* || true

ARTIFACT_BRANCH="${REPO_BRANCH:-openwrt}"
rm -rf "$ARTIFACT_BRANCH"
mkdir -p "$ARTIFACT_BRANCH"
cp -rf openwrt/bin/targets "$ARTIFACT_BRANCH"/
if [ -d openwrt/bin/packages ]; then
	cp -rf openwrt/bin/packages "$ARTIFACT_BRANCH"/
fi

step "Local output"
ARTIFACT_NAME="${VERSION}_${TARGET}"
ARTIFACT_ZIP="/host/output/${ARTIFACT_NAME}.zip"
rm -f "$ARTIFACT_ZIP"
shopt -s nullglob
artifact_inputs=()
[ -d firmware ] && artifact_inputs+=(firmware)
[ -d "$ARTIFACT_BRANCH" ] && artifact_inputs+=("$ARTIFACT_BRANCH")
artifact_inputs+=(openwrt/bin/packages/*/base/*-firmware*)
artifact_inputs+=(openwrt/bin/targets)
shopt -u nullglob
if [ "${#artifact_inputs[@]}" -eq 0 ]; then
	echo "No artifact inputs found." >&2
	exit 1
fi
zip -r -q "$ARTIFACT_ZIP" "${artifact_inputs[@]}"
echo "Local artifact zip: $ARTIFACT_ZIP"
find /host/output -type f | sort >/host/output/logs/output-files.txt

step "Openwrt-AutoBuild.yml / Deploy imagebuilder to server"
echo "Local run: skipped remote ssh deploy."

step "Openwrt-AutoBuild.yml / Upload firmware for artifact"
echo "Local run: artifact zip is available at $ARTIFACT_ZIP."

step "Openwrt-AutoBuild.yml / Create release"
echo "Local run: skipped release creation."

step "Openwrt-AutoBuild.yml / Upload firmware for release"
echo "Local run: skipped release upload."

step "Openwrt-AutoBuild.yml / Notifications and cleanup"
echo "Local run: skipped remote notifications, workflow-run deletion, and release deletion."
RUNNER_SCRIPT

chmod +x /tmp/local-actions-runner.sh
sudo -E -u runner -H bash /tmp/local-actions-runner.sh
CONTAINER_SCRIPT
