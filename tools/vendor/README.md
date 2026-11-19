# 打包工具

`mkbootimg/` 中的脚本分别来自 AOSP 的 `mkbootimg.py` 与
`unpack_bootimg.py`，用于打包与解包 Android boot 镜像。文件头部保留
原始版权声明。`gki/generate_gki_certificate.py` 是 `mkbootimg.py` 的
导入依赖，生成 GKI 证书时需要。

许可证为 `Apache-2.0`，全文见 `mkbootimg/licenses/Apache-2.0.txt`。

`scripts/pack-boot.sh` 优先使用这里的 `mkbootimg.py`，主机安装了
`mkbootimg` 时也可以使用系统命令。

`unpack_bootimg.py` 用于从原厂 `boot.img` 解出 `kernel`、`ramdisk`
与 `dtb`。
