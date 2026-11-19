#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 各脚本共用的默认路径。
#
# 仓库根目录的 .env 存在时先加载，用于指向本机的内核树、工具链与 boot 底包；
# 未设置 .env 时全部退回仓库内的默认位置，便于公开仓库直接使用。

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ -f "$ROOT/.env" ]; then
	# 导出到子进程，flash-boot.sh 调用的 edl-dby.sh 需要读取这些变量。
	set -a
	# shellcheck disable=SC1091
	. "$ROOT/.env"
	set +a
fi

KERNEL_SRC=${KERNEL_SRC:-$ROOT/kernel/src}
KERNEL_ORIGIN=${KERNEL_ORIGIN:-}
KSU_DIR=${KSU_DIR:-$ROOT/ksu/src}
KERNEL_PATCH_DIR=${KERNEL_PATCH_DIR:-$ROOT/kernel/patches}
KSU_PATCH_DIR=${KSU_PATCH_DIR:-$ROOT/ksu/patches}
TOOLCHAIN_DIR=${TOOLCHAIN_DIR:-$ROOT/toolchain}
CLANG_DIR=${CLANG_DIR:-$TOOLCHAIN_DIR/clang+llvm-11.1.0}
BINUTILS_DIR=${BINUTILS_DIR:-$TOOLCHAIN_DIR/ubuntu-binutils/usr}
CONFIG=${CONFIG:-$ROOT/kernel/defconfig}
OUT_DIR=${OUT_DIR:-$ROOT/out}
LOG_DIR=${LOG_DIR:-$ROOT/logs}

require_file() {
	local path=$1 hint=$2
	if [ ! -e "$path" ]; then
		printf '缺少 %s\n%s\n' "$path" "$hint" >&2
		exit 1
	fi
}
