# 本地构建脚本说明

## reproduce-x86_64-actions-docker.sh

这个脚本用于在本地 Docker 里复现 GitHub Actions 的 x86_64 构建流程。

它会模拟 `repo-dispatcher.yml` 和 `Openwrt-AutoBuild.yml` 里的主要步骤：

- 复制本地 Kwrt 工作区
- 读取 `devices/common` 和 `devices/x86_64` 的配置
- 克隆 OpenWrt 源码
- 执行 common 和 x86_64 的 `diy.sh`
- 应用 `.config`、`default-settings` 和 patches
- 执行 `make defconfig` 和 `make`
- 把固件和 packages 产物整理到 `.local-actions`

## 常用启动方式

在 Kwrt 仓库目录下直接运行：

```sh
cd /Users/litongliang/Repositories/Git/GitHub/Kwrt
./scripts/reproduce-x86_64-actions-docker.sh
```

`TARGET` 默认就是 `x86_64`，所以普通 x86_64 构建不需要额外传参数。

## 常见用法

```sh
# 默认 x86_64 构建
./scripts/reproduce-x86_64-actions-docker.sh

# 模拟带 event action 的 x86_64 dispatch
EVENT_PARAM="x86_64" ./scripts/reproduce-x86_64-actions-docker.sh

# 指定版本号，效果类似 Actions 里的 event action 带版本
EVENT_PARAM="x86_64 10.04" ./scripts/reproduce-x86_64-actions-docker.sh

# 使用当前 HEAD 的干净导出，不带工作区未提交改动
SOURCE_TREE=head ./scripts/reproduce-x86_64-actions-docker.sh

# 指定输出目录
OUTPUT_DIR=/tmp/kwrt-x86_64-build ./scripts/reproduce-x86_64-actions-docker.sh
```

## 常用环境变量

- `TARGET`：构建目标，默认 `x86_64`
- `EVENT_PARAM`：模拟 Actions 的 event action 参数，可包含 `pkg`、`tags`、`ssh`、`nocache`、`notg`、版本号等文本
- `SOURCE_TREE`：源码来源，默认 `worktree`；设为 `head` 时使用 `git archive HEAD` 的干净导出
- `OUTPUT_DIR`：输出目录，默认 `.local-actions/<target>-<timestamp>`
- `IMAGE`：Docker 镜像，默认 `ubuntu:24.04`
- `DOCKER_PLATFORM`：手动指定 Docker 平台
- `TOKEN_KIDDIN9` 或 `REPO_TOKEN`：可选 GitHub token，用于 GitHub API 调用

## 输出位置

默认输出在：

```text
.local-actions/<target>-<timestamp>/
```

常见文件：

```text
logs/reproduce.log      # 本地构建完整日志
logs/final.config       # make defconfig 后的最终配置
logs/make-Vs.log        # make 失败后 fallback 到 make V=s 时的日志
logs/output-files.txt   # 输出文件列表
<version>_<target>.zip  # 本地整理出的产物压缩包
```

## 注意事项

- 需要本机已安装并启动 Docker。
- 默认会使用当前工作区内容，也就是未提交改动也会参与构建。
- 如果想模拟 GitHub Actions 的干净 checkout，用 `SOURCE_TREE=head`。
- 脚本使用 `devices/common/diy.sh` 里的远程 `src-git` feed，不会 rsync 本地 `op-packages`。这样 LuCI 包版本号生成逻辑和 GitHub Actions 保持一致。
- 远程 CI 专属步骤，例如上传 artifact、创建 release、Telegram 通知、SSH 部署、清理 workflow runs，本地只会打印跳过，不会真正执行。
