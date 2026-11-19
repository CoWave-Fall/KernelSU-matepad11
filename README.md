# KernelSU for Huawei MatePad 11 2021（DBY-W09）

在 HarmonyOS 4.2 原厂 4.19.157 内核上内置 KernelSU v3.3.1，保留原厂系统，
仅替换 `boot` 分区。以下功能在 `DBY-W09`、内核 `4.19.157-perf`、KernelSU
管理器 v3.3.1（内核版本码 `32680`）上实机验证。

| 功能 | 状态 |
|:--|:--|
| `su` 提权 | 可用，进程上下文 `u:r:ksu:s0`，SELinux `Enforcing` |
| 管理器与 `ksud` | 可用，`ksud 3.3.1 (uapi: 5)` 安装到 `/data/adb/ksud` |
| 模块 | 可用，`system/` 挂载需要 `meta-overlayfs` |
| `kernel_umount` | 可用，新启动的进程看不到模块 overlay |
| `sulog`、`adb_root`、`shell_su_adb_only` | 可用 |
| 动态策略注入 | 可用，`ksud sepolicy patch` 原地改写 4.19 策略库 |
| `selinux_hide` | 可用 |

## 构建

依赖：

```bash
sudo apt install build-essential bc bison flex libssl-dev python3 git patch \
  binutils-aarch64-linux-gnu gcc-aarch64-linux-gnu usbutils
```

准备内核源码与 clang 11.1.0：

```bash
# 从华为开源代码发布页下载 DBY-W09_HarmonyOS4.0.0_opensource.tar.gz
# <https://consumer.huawei.com/en/opensource/detail/>
# SHA-256 52c38060cf2990e44bbc556f39271f6e97af90777a300165443946aa97c72e5f
mkdir -p .tmp toolchain
tar -xzf DBY-W09_HarmonyOS4.0.0_opensource.tar.gz -C .tmp

curl -LO https://github.com/llvm/llvm-project/releases/download/llvmorg-11.1.0/clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-20.10.tar.xz
tar -C toolchain -xf clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-20.10.tar.xz
mv toolchain/clang+llvm-11.1.0-x86_64-linux-gnu-ubuntu-20.10 toolchain/clang+llvm-11.1.0
```

应用补丁并编译：

```bash
cp .env.example .env
# .env 写入 KERNEL_ORIGIN=$PWD/.tmp/Code_Opensource/kernel 与 BINUTILS_DIR=/usr
scripts/setup.sh
scripts/build.sh          # 产物 out/Image.gz
```

## 打包与刷写

```bash
export EDL_PROGRAMMER=/path/to/programmer.elf
tools/host/edl-dby.sh r boot dumps/boot-stock.img --lun=4
python3 tools/vendor/mkbootimg/unpack_bootimg.py \
  --boot_img dumps/boot-stock.img --out .tmp/boot-unpack
# .env 写入 STOCK_BOOT=dumps/boot-stock.img、
# RAMDISK=.tmp/boot-unpack/ramdisk、DTB=.tmp/boot-unpack/dtb
scripts/pack-boot.sh      # 产物 out/boot-ksu.img
scripts/flash-boot.sh out/boot-ksu.img   # 设备置于 9008 模式
```

## 使用

设备启动后安装官方 KernelSU v3.3.1 管理器 APK，按提示完成初始化，之后
`su` 与模块由管理器提供。刷回原厂镜像：

```bash
scripts/flash-boot.sh dumps/boot-stock.img
```

## 实机验证

在 `DBY-W09` 上逐项执行，全部得到预期结果：

| 检查 | 命令 | 结果 |
|:--|:--|:--|
| 提权 | `su -c id` | `uid=0` |
| 进程上下文 | `su -c 'cat /proc/self/attr/current'` | `u:r:ksu:s0` |
| SELinux | `getenforce` | `Enforcing` |
| 策略注入 | `su -c 'ksud sepolicy patch "type ksu_probe domain"'` | 返回 `0`，策略长度 `2634508 -> 2634569` |
| 模块挂载 | `su -c 'mount \| grep KSU'` | `KSU on /system` |
| 应用侧隐藏 | 应用 uid 查询 `u:object_r:ksu:s0` | `-22` |
| 状态页副本 | 应用 uid 读 `sequence` | `0`（注入后线上值为 `2`） |
| 启动稳定性 | `getprop persist.device_config.attempted_boot_count` | `0` |
| 启动事件 | 模块脚本执行 | `post-fs-data`、`services`、`boot-completed` 均触发 |

补丁在原始归档上顺序应用，无拒绝与偏移；由归档经 `scripts/setup.sh`
处理后可完成 `Image.gz` 构建。

## 已知限制

- 补丁面向华为 HarmonyOS 4.0.0 开源包中的 4.19.157 内核，其他内核版本的
  API 与策略结构需要重新适配。
- `boot` 分区为 96 MiB，镜像按整分区打包，并清零 `24449024` 处的 vbmeta
  结构让 ABL 跳过 AVB 校验。刷写前先备份原厂 `boot`。
- 内核关闭 `CONFIG_RANDOMIZE_BASE` 与 `CONFIG_MODULE_SIG`。

## 许可

脚本、原创代码与文档为 `GPL-3.0-or-later`，内核补丁为 `GPL-2.0-only`，
`tools/vendor/` 沿用 `Apache-2.0`。全文见 `LICENSE` 与 `LICENSES/`。
