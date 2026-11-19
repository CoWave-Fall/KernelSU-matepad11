#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 以设备配套的 Firehose programmer 调用 edl。
#
# edl 未指定 --loader 时会到自身安装目录的 Loaders 子目录查找与设备匹配的
# programmer。这里统一显式传入 EDL_PROGRAMMER 指向的文件。
#
# 用法：tools/host/edl-dby.sh <edl 子命令> [参数...]
#   EDL_PROGRAMMER=/path/to/programmer.elf tools/host/edl-dby.sh printgpt
#   tools/host/edl-dby.sh rs 0 0x2000 dumps/lba0-hdr.img
set -euo pipefail

PROGRAMMER=${EDL_PROGRAMMER:-}

if ! command -v edl >/dev/null; then
	printf '未找到 edl 命令，请先安装 edl 并放入 PATH\n' >&2
	exit 1
fi
if [ -z "$PROGRAMMER" ]; then
	printf '未设置 EDL_PROGRAMMER，需要指向设备配套的 Firehose programmer\n' >&2
	exit 1
fi
if [ ! -f "$PROGRAMMER" ]; then
	printf '缺少 programmer：%s\n' "$PROGRAMMER" >&2
	exit 1
fi

exec edl --loader="$PROGRAMMER" "$@"
