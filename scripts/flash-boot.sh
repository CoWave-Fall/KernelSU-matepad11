#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 写入 boot 分区并回读比对，然后复位启动。
# 用法：flash-boot.sh <boot 分区镜像>
#
# 需要设备处于 9008 模式，并设置 EDL_PROGRAMMER 指向设备配套的 Firehose
# programmer。设置了 EDL_LOCK 时整个刷写过程持有该文件锁。
set -euo pipefail

. "$(dirname "$0")/lib.sh"

EDL_SCRIPT=${EDL_SCRIPT:-$ROOT/tools/host/edl-dby.sh}
IMG=${1:?用法: flash-boot.sh <boot.img>}
RB="$OUT_DIR/boot-readback.img"

require_file "$IMG" '先运行 scripts/pack-boot.sh 生成 boot 镜像。'
require_file "$EDL_SCRIPT" '缺少 tools/host/edl-dby.sh。'
mkdir -p "$OUT_DIR"

if ! lsusb | grep -q "05c6:9008"; then
	printf '请把平板切到 9008，脚本将等待最长 10 分钟。\n'
	for _ in $(seq 1 600); do
		lsusb | grep -q "05c6:9008" && break
		sleep 1
	done
fi
lsusb | grep -q "05c6:9008" || {
	printf '等待进入 9008 超时\n' >&2
	exit 1
}

if [ -n "${EDL_LOCK:-}" ]; then
	exec 9>"$EDL_LOCK"
	flock -n 9 || {
		printf '设备锁被占用：%s\n' "$EDL_LOCK" >&2
		exit 1
	}
fi

"$EDL_SCRIPT" w boot "$IMG"
# 按分区名整块回读，覆盖 kernel、ramdisk 与 dtb 全部区域。
"$EDL_SCRIPT" r boot "$RB" --lun=4

cmp "$IMG" "$RB"
printf '回读 %d 字节一致\n' "$(stat -c %s "$IMG")"

"$EDL_SCRIPT" reset --resetmode=reset 2>&1 | tail -3 || true
printf '已复位启动\n'
