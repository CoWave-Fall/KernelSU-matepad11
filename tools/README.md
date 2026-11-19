# 工具

| 目录 | 内容 |
|:--|:--|
| `host/` | 主机侧 EDL 调用脚本，统一传入 Firehose programmer |
| `device/` | 设备侧验证程序 |
| `vendor/` | AOSP 打包与解包工具 |

## 主机侧

| 文件 | 作用 |
|:--|:--|
| `host/edl-dby.sh` | 调用 `edl`，按 `EDL_PROGRAMMER` 指定 programmer |

## 设备侧

| 文件 | 作用 |
|:--|:--|
| `device/seltest.c` | 以指定 uid 查询 selinuxfs 节点，验证 `selinux_hide` |
| `device/dropuid.c` | 降权并可脱离进程树后执行命令，验证 `shell_su_adb_only` |

`dropuid` 的编译方式：

```bash
aarch64-linux-gnu-gcc -static -O2 -o .tmp/dropuid tools/device/dropuid.c
adb push .tmp/dropuid /data/local/tmp/dropuid
```

示例：在 `shell_su_adb_only` 开启时，脱离 adbd 的 uid 2000 进程看不到
`/system/bin/su`：

```bash
adb shell su -c '/data/local/tmp/dropuid --orphan --shell 2000 /system/bin/sh -c "ls -l /system/bin/su; /system/bin/su -c id" >/data/local/tmp/out 2>&1'
adb shell cat /data/local/tmp/out
```
