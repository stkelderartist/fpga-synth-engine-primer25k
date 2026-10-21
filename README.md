# fpga-synth-engine · Tang Primer 25K

基于 **Sipeed Tang Primer 25K 核心板 + Dock 60033 底板**的实时多音色电子乐器引擎。
从 [M3-Grant/fpga-synth-engine](https://github.com/M3-Grant/fpga-synth-engine) 的 `8e546d3` 移植，保留原作者代码和历史资料。本分支默认构建目标已切换至 25K。

## 当前平台

| 项目 | 配置 |
| --- | --- |
| FPGA | GW5A-25，MG121N；默认 `GW5A-LV25MG121NC1/I0`、Device Version A |
| 早期核心板 | 芯片标记 NES 的板卡按实际型号选择 `GW5A-LV25MG121NES`，见移植指南 |
| 主时钟 | 50 MHz，FPGA 球位 E2；不使用 PLL |
| I2S | Philips 格式，16 位 PCM，32 BCK/声道，左右相同 |
| BCK / LRCK | 3.125 MHz / **48,828.125 Hz**，`BCK_HALF=8` |
| 演奏 | 12 路高有效输入，C4～B4，4 声部；Dock S1 可直接试奏 C4 |
| 音色 | 三角、方波、锯齿、25% 脉冲；Dock S2 循环切换 |
| 音频硬件 | **外接** MAX98357A 模块 + 喇叭，或 PCM5102A + 有源音箱 |

**Dock 25K 没有 Nano 20K 的板载音频功放和六颗用户 LED。旧的 51/54/55/56 等数字管脚约束不能沿用。**

## 快速开始

1. 按 [25K 移植指南](docs/Tang-Primer-25K移植指南.md)连接外部 I2S 模块，先运行 440 Hz 测试。
2. 安装支持 GW5A-25 的 Gowin IDE（Sipeed 要求 V1.9.9 Beta-4 或更新版本），核对芯片丝印和 Device Version A。
3. 仿真需 Python 3 和 Icarus Verilog，二者加入 PATH：

```sh
python code/run_sim.py
```

Windows 也可运行 `code/run_sim_all.bat` 或 `code/run_sim_all.ps1`。支持 `--iverilog` 和 `--vvp` 指定完整工具路径。

4. 在 PowerShell 中构建（Gowin 安装目录由本机指定）：

```powershell
./code/synth/build.ps1 -Target tone_test -GowinHome 'D:/Gowin/你的安装目录'
./code/synth/build.ps1 -Target synth_board12 -GowinHome 'D:/Gowin/你的安装目录'
```

先只检查工程输入并生成 Tcl：

```powershell
./code/synth/build.ps1 -Target synth_board12 -GenerateOnly
```

脚本同时添加 `.cst` 与 20 ns `.sdc`，配置 CPU、SSPI、READY 复用。生成的码流位于 `build/tang_primer25k/<target>/impl/pnr/`。使用 Gowin Programmer 手动选择实际器件和外部 Flash；初次建议 SRAM 下载。

GUI 工程位于 `code/boards/tang_primer25k/{tone_test,synth_board12}.gprj`，GUI 用户还须按指南设置双用途管脚复用。

## 目录

```text
code/boards/tang_primer25k/  25K 顶层、两套 CST、SDC、GUI 工程和接线入口
code/rtl/                   共享合成内核，保留旧顶层供历史回归
code/sim/tb_primer25k.v      50 MHz 实际速率下的板级自检
code/synth/build.ps1        默认 25K 构建脚本
code/synth/build_nano20k.ps1 历史 Nano 构建，仅用于原板
code/run_sim.py             跨平台 11 套回归，检查错误标记与退出码
docs/Tang-Primer-25K移植指南.md 当前硬件、音准和烧录指南
docs/legacy-nano20k/        原入口文档备份
```

其余旧文档均标有历史提示；`iterations/` 和旧 beta ZIP、音频/频谱图是 Nano 20K 历史快照，不是 25K 的验证结果。

## 验证范围

新增测试覆盖 25 个音的 FCW、BCK/LRCK 周期、440 Hz 相位变化、I2S 串行解码、上电静音、三键复音、12 键事件、功放门控以及 S1/S2。原有 10 套测试仍执行。GitHub Actions 在 push/PR 后运行相同仿真。

本次环境没有 Gowin 工具链和实体板卡，因此**不提供已验证码流，不宣称综合、布局布线、时序收敛或实板音频通过**。下载前需完成本机 Gowin 构建及接线、波形和音准检查。见 [验证记录](docs/25K验证记录.md)。

## 来源

- [Sipeed Tang Primer 25K 官方介绍](https://wiki.sipeed.com/hardware/zh/tang/tang-primer-25k/primer-25k.html)
- [Sipeed 官方示例](https://github.com/sipeed/TangPrimer-25K-example)，核对版本 `27c1737b687369f46baff9cf621cd7499a1b7fd4`
- [Sipeed 官方原理图目录](https://dl.sipeed.com/shareURL/TANG/Primer_25K/02_Schematic)

原仓库没有明确开源许可证，本移植不额外授予原代码的许可；请保留原作者署名，分发和使用范围需与原作者确认。
