# Tang Primer 25K 构建入口

默认 `build.ps1` 生成并构建 GW5A-25/MG121N 工程：

```powershell
./code/synth/build.ps1 -Target tone_test -GenerateOnly
./code/synth/build.ps1 -Target synth_board12 -GowinHome 'D:/Gowin/你的安装目录'
```

默认生产器件 `GW5A-LV25MG121NC1/I0`。早期 NES 板卡可传 `-Device GW5A-LV25MG121NES`；请按实际丝印确认，并在 GUI 中核对 Device Version A。所有文件路径从脚本位置解析，与当前工作目录无关。

输出 `build/tang_primer25k/<target>/impl/pnr/<target>.fs`。脚本验证工具退出码和码流更新时间，不自动烧录。见 [完整指南](../../docs/Tang-Primer-25K移植指南.md)。

`build_nano20k.ps1` 是保留的原 Nano 20K 构建，仅用于原板；旧 SSPI 管脚和自动烧录参数不适用于 25K。
