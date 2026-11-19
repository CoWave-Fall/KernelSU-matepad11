#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 把 Image.gz 打包成 boot 分区镜像：以原厂 boot.img 为底，保留 footer，
# 清零 vbmeta 区域让 ABL 跳过 AVB 校验。
# 用法：pack-boot.sh [Image.gz] [ramdisk] [dtb] [输出镜像]
set -euo pipefail

. "$(dirname "$0")/lib.sh"

KERNEL=${1:-$OUT_DIR/Image.gz}
RAMDISK=${2:-${RAMDISK:-}}
DTB=${3:-${DTB:-}}
OUT_IMG=${4:-$OUT_DIR/boot-ksu.img}

require_file "$KERNEL" '先运行 scripts/build.sh 生成 Image.gz。'
require_file "$STOCK_BOOT" '请用 STOCK_BOOT 指向原厂 boot 分区镜像。'
require_file "$RAMDISK" '请用 RAMDISK 指向从原厂 boot.img 解包出的 ramdisk。'
require_file "$DTB" '请用 DTB 指向从原厂 boot.img 解包出的 dtb。'

# 设备参数：boot 分区 96 MiB，vbmeta 结构位于 24449024 字节处。
PARTITION_SIZE=100663296
VBMETA_OFFSET=24449024
VBMETA_SIZE=4096

CMDLINE=${CMDLINE:-"earlycon=msm_geni_serial,0xa90000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 loop.max_part=7 cgroup.memory=nokmem,nosocket reboot=panic_warm androidboot.selinux=enforce unmovable_isolate1=2:256M,3:312M,4:348M buildvariant=user"}
# 诊断构建可以追加内核参数，例如 EXTRA_CMDLINE=block_modules=foo。
if [ -n "${EXTRA_CMDLINE:-}" ]; then
	CMDLINE="$CMDLINE $EXTRA_CMDLINE"
fi

# 优先使用仓库内置的 AOSP 工具，其次是 PATH 里的 mkbootimg。
if [ -f "$ROOT/tools/vendor/mkbootimg/mkbootimg.py" ]; then
	MKBOOTIMG=(python3 "$ROOT/tools/vendor/mkbootimg/mkbootimg.py")
elif command -v mkbootimg >/dev/null; then
	MKBOOTIMG=(mkbootimg)
else
	printf '缺少 mkbootimg，也没有 tools/vendor/mkbootimg/mkbootimg.py\n' >&2
	exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"${MKBOOTIMG[@]}" \
	--kernel "$KERNEL" \
	--ramdisk "$RAMDISK" \
	--dtb "$DTB" \
	--cmdline "$CMDLINE" \
	--base 0x0 \
	--kernel_offset 0x00008000 \
	--ramdisk_offset 0x02000000 \
	--tags_offset 0x00000100 \
	--dtb_offset 0x01f00000 \
	--pagesize 4096 \
	--header_version 2 \
	--os_version 11.0.0 \
	--os_patch_level 2020-11 \
	-o "$tmp/boot.img"

cp "$STOCK_BOOT" "$tmp/part.img"
dd if="$tmp/boot.img" of="$tmp/part.img" conv=notrunc status=none
dd if=/dev/zero of="$tmp/part.img" bs=1 seek="$VBMETA_OFFSET" count="$VBMETA_SIZE" conv=notrunc status=none

size=$(stat -c %s "$tmp/part.img")
if [ "$size" -ne "$PARTITION_SIZE" ]; then
	printf '原厂镜像大小 %d 与 boot 分区容量 %d 存在差异\n' "$size" "$PARTITION_SIZE" >&2
	exit 1
fi

mv "$tmp/part.img" "$OUT_IMG"
ls -lh "$OUT_IMG"
sha256sum "$OUT_IMG"
