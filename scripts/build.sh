#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 构建带 KernelSU v3.3.1 的 4.19.157 内核。
# 用法：scripts/build.sh
set -euo pipefail

. "$(dirname "$0")/lib.sh"

require_file "$KERNEL_SRC/Makefile" \
	'请把 4.19.157 内核树放到 kernel/，或用 KERNEL_SRC 指向已有树。'
require_file "$CLANG_DIR/bin/clang" \
	'请安装 clang 11.1.0 工具链，或用 CLANG_DIR 指向已有目录。'
require_file "$BINUTILS_DIR/bin/aarch64-linux-gnu-ld" \
	'请准备 Ubuntu binutils 交叉工具，或用 BINUTILS_DIR 指向已有目录。'

LOG="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$OUT_DIR" "$LOG_DIR"

export LD_LIBRARY_PATH="$BINUTILS_DIR/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$CLANG_DIR/bin:$BINUTILS_DIR/bin:$PATH"

# 华为源码保留老式函数定义与隐式声明，clang 11 会按 -Werror 终止编译。
export KCFLAGS="-Wno-error=strict-prototypes -Wno-error=implicit-function-declaration"
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-KernelSU}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-local}

MAKE_ARGS=(
	-C "$KERNEL_SRC"
	ARCH=arm64
	CROSS_COMPILE=aarch64-linux-gnu-
	CC="$CLANG_DIR/bin/clang"
	CLANG_TRIPLE=aarch64-linux-gnu-
	LD="$BINUTILS_DIR/bin/aarch64-linux-gnu-ld"
	AR="$BINUTILS_DIR/bin/aarch64-linux-gnu-ar"
	NM="$BINUTILS_DIR/bin/aarch64-linux-gnu-nm"
	OBJCOPY="$BINUTILS_DIR/bin/aarch64-linux-gnu-objcopy"
	OBJDUMP="$BINUTILS_DIR/bin/aarch64-linux-gnu-objdump"
	STRIP="$BINUTILS_DIR/bin/aarch64-linux-gnu-strip"
	HOSTCC="$CLANG_DIR/bin/clang"
	HOSTCXX="$CLANG_DIR/bin/clang++"
	HOSTCFLAGS="-fcommon -DOPENSSL_ENGINE_STUBS"
)

# 每次从配置文件重建，清掉上一轮诊断构建留下的选项。
if [ -f "$CONFIG" ]; then
	cp "$CONFIG" "$KERNEL_SRC/.config"
fi

grep -q '^CONFIG_KSU=y$' "$KERNEL_SRC/.config" || {
	printf '配置里 KernelSU 未启用，终止构建\n' >&2
	exit 1
}
grep -q '^# CONFIG_HW_ROOT_SCAN is not set$' "$KERNEL_SRC/.config" || {
	printf '配置里 HW_ROOT_SCAN 未关闭，终止构建\n' >&2
	exit 1
}

{
	make "${MAKE_ARGS[@]}" olddefconfig
	make "${MAKE_ARGS[@]}" -j"$(nproc)" Image.gz
} 2>&1 | tee "$LOG"

cp "$KERNEL_SRC/arch/arm64/boot/Image.gz" "$OUT_DIR/Image.gz"
sha256sum "$OUT_DIR/Image.gz" | tee -a "$LOG"
# 先落到文件再提取版本串，避免 strings 被下游 grep -m1 提前关闭而触发 SIGPIPE。
strings "$KERNEL_SRC/arch/arm64/boot/Image" >"$OUT_DIR/version.txt"
grep -m1 'Linux version' "$OUT_DIR/version.txt" | tee -a "$LOG"
