#!/usr/bin/env bash
# 给云端环境安装 Godot，幂等。二进制放在 /usr/local/bin/godot。
set -euo pipefail

GODOT_VERSION="4.8-dev7"
GODOT_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
INSTALL_PATH="/usr/local/bin/godot"

if [[ -x "$INSTALL_PATH" ]]; then
	# 官方 --version 是 4.8.dev7，标签是 4.8-dev7。
	if "$INSTALL_PATH" --version 2>/dev/null | grep -q "4.8.dev7"; then
		echo "godot ${GODOT_VERSION} 已安装"
		exit 0
	fi
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	unzip \
	libfontconfig1 \
	libx11-6 \
	libxcursor1 \
	libxinerama1 \
	libxrandr2 \
	libxi6 \
	libgl1 \
	libxext6 \
	libxrender1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/godot.zip" "$GODOT_URL"
unzip -o "$tmp/godot.zip" -d "$tmp"
bin="$(find "$tmp" -maxdepth 1 -type f -name 'Godot*' ! -name '*.zip' | head -n 1)"
if [[ -z "$bin" ]]; then
	echo "解压后没找到 Godot 可执行文件" >&2
	exit 1
fi
sudo install -m 755 "$bin" "$INSTALL_PATH"
"$INSTALL_PATH" --version
