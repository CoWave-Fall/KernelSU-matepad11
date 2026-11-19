#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 重建 KernelSU 集成：检出固定版本、挂接符号链接、应用补丁、恢复配置文件。
# 内核树存在时只做幂等更新，可以直接重复执行。
# 用法：scripts/setup.sh
set -euo pipefail

. "$(dirname "$0")/lib.sh"

KSU_TAG=${KSU_TAG:-v3.3.1}

# KERNEL_ORIGIN 用于首次复制内核树；已有源码树时由 KERNEL_SRC 指向它。
if [ ! -d "$KERNEL_SRC" ]; then
	if [ -z "$KERNEL_ORIGIN" ]; then
		printf '内核树不存在：%s\n请用 KERNEL_ORIGIN 指向华为开源包中的 Code_Opensource/kernel，或用 KERNEL_SRC 指向已有树。\n' "$KERNEL_SRC" >&2
		exit 1
	fi
	require_file "$KERNEL_ORIGIN" \
		"内核树不存在：$KERNEL_SRC。请用 KERNEL_ORIGIN 指向华为开源包中的 Code_Opensource/kernel，或用 KERNEL_SRC 指向已有树。"
	cp -a --reflink=auto "$KERNEL_ORIGIN" "$KERNEL_SRC"
fi

if [ ! -d "$KSU_DIR/kernel" ]; then
	git clone --branch "$KSU_TAG" --single-branch \
		https://github.com/tiann/KernelSU "$KSU_DIR"
fi

# 旧版集成目录移入 Archived 保留，替代直接删除。
if [ -e "$KERNEL_SRC/drivers/kernelsu" ] && [ ! -L "$KERNEL_SRC/drivers/kernelsu" ]; then
	mkdir -p "$ROOT/Archived"
	mv "$KERNEL_SRC/drivers/kernelsu" "$ROOT/Archived/kernelsu-$(date +%Y%m%d-%H%M%S)"
fi
# 内核树可以放在仓库外，符号链接用绝对路径避免指错。
ln -sfn "$KSU_DIR/kernel" "$KERNEL_SRC/drivers/kernelsu"

for p in "$KERNEL_PATCH_DIR"/*.patch; do
	[ -e "$p" ] || continue
	# 逐行匹配会因已有插入而错位，改用反向应用预检测断补丁是否已经打上。
	if patch -p1 -d "$KERNEL_SRC" --dry-run --reverse --force <"$p" >/dev/null 2>&1; then
		printf '跳过已应用的内核补丁：%s\n' "$(basename "$p")"
		continue
	fi
	patch -p1 -d "$KERNEL_SRC" <"$p"
done

# 挂接由内核补丁写入，打完补丁后再核对，缺失说明补丁目录不完整。
grep -q 'drivers/kernelsu/Kconfig' "$KERNEL_SRC/drivers/Kconfig" || {
	printf 'drivers/Kconfig 缺少 kernelsu 挂接\n' >&2
	exit 1
}
grep -q 'CONFIG_KSU.*kernelsu/' "$KERNEL_SRC/drivers/Makefile" || {
	printf 'drivers/Makefile 缺少 kernelsu 挂接\n' >&2
	exit 1
}

for p in "$KSU_PATCH_DIR"/*.patch; do
	[ -e "$p" ] || continue
	if git -C "$KSU_DIR" apply --check "$p" 2>/dev/null; then
		git -C "$KSU_DIR" apply "$p"
	else
		printf '跳过已应用或冲突的 KernelSU 补丁：%s\n' "$(basename "$p")"
	fi
done

if [ -f "$CONFIG" ]; then
	cp "$CONFIG" "$KERNEL_SRC/.config"
fi
