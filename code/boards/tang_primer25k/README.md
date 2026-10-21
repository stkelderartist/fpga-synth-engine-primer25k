# Tang Primer 25K + Dock 60033

本目录为当前默认板卡。完整接线、器件选择、GUI 复用设置、构建和验证边界见 [移植指南](../../../docs/Tang-Primer-25K移植指南.md)。

| 构建目标 | 顶层 | 用途 |
| --- | --- | --- |
| tone_test | primer25k_tone_top | 440 Hz 方波，先打通外接 I2S 链路 |
| synth_board12 | primer25k_top | 12 键 4 声部，S1 试奏 C4，S2 切换四种波形 |

固定 50 MHz/E2，BCK_HALF=8，fs=48828.125 Hz。CST 使用 MG121N 球位，不能替换为 Nano 数字引脚。READY/E8 高有效，须启用 READY as GPIO；L6/K6 属于 USB，不用作状态灯。

推荐用 `../../synth/build.ps1` 构建，自动加载 CST、SDC 和双用途设置。GUI 打开 `.gprj` 后必须手动核对器件版本 A、顶层和 CPU/SSPI/READY 复用。当前没有经过 Gowin 布局布线和实板验证的码流。
