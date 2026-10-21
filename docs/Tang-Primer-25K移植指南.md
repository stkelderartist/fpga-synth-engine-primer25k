# Tang Primer 25K 移植与上板指南

## 适用硬件和器件

适用于 Sipeed Tang Primer 25K 核心板，搭配 **Dock 60033**。仅有核心板时，需要自行按相同球位引出 3.3 V IO、电源和时钟。

默认型号为官方当前介绍中的 `GW5A-LV25MG121NC1/I0`，Device Version **A**。较早的 Sipeed 示例和核心板有 `GW5A-LV25MG121NES` 标记；应核对实际芯片与 IDE 器件库，必要时在构建命令传 `-Device GW5A-LV25MG121NES`。禁止只按“25K”字样选择不同封装/版本。

官方要求 Gowin IDE V1.9.9 Beta-4 或更新。芯片型号/版本必须在 IDE 与 Programmer 两边一致。

## 音频与时钟

25K 主时钟 50 MHz 接 FPGA 球位 **E2**。现有 I2S 内核每声道 32 BCK，因此：

```text
BCK_HALF = 8
BCK = 50,000,000 / (2 × 8) = 3,125,000 Hz
fs  = BCK / 64 = 48,828.125 Hz
FCW = round(f × 2^32 / fs)
A4 440 Hz FCW = 38,702,809
```

这是固定且无分数分频抖动的采样率，**不是标准 48 kHz**。若需要标准 48 kHz，需要设计适合本器件的音频 PLL 时钟链、时序约束和对应 FCW；当前未实现。

共享 `note_table` 新增 `CLOCK_HZ`、`BCK_HALF` 参数，`synth_top` 自动透传。查表用 64 位常量运算根据真实速率缩放原表，综合时折叠，无运行时除法。25 个音的误差小于 0.00002 Hz（晶振误差另计）。原默认值 27 MHz/4 保留供 Nano 回归。

改时钟/分频必须同步更改表参数和 SDC。重新生成共享表时从仓库根目录运行：

```sh
python code/tools/gen_fcw.py 27e6 4 --out code/rtl/note_table.v
```

生成器保留参数化逻辑；25K 顶层显式传 50 MHz/8，不能直接复用未经改参数的旧顶层。

## 外部音频接线

**25K Dock 没有 Nano 20K 的板载 MAX98357A 或 SPK 焊盘。**

以下编号按官方 Dock 60033 原理图第 1 页；CST 中的 `G5` 等是 **FPGA 封装球位**，`J6-7` 是底板接插件针号，两者不能混用。实物可能未印接插件编号，请按原理图与插座 Pin 1 标记定位，不能凭照片左右方向接线。

| 信号 | FPGA 球位 | Dock 接插件 | 外部模块 |
| --- | --- | --- | --- |
| i2s_bck | G5 | J6-7 | MAX98357A BCLK / PCM5102A BCK |
| i2s_lrck | F5 | J6-8 | LRC / LRCK |
| i2s_din | G7 | J6-9 | DIN |
| pa_en | G8 | J6-10 | 可选：MAX98357A SD_MODE/EN |
| 3.3 V | — | J6-3 或 J6-4 | 支持 3.3 V 供电的模块 VCC/VIN |
| GND | — | J6-1 或 J6-2 | 模块 GND，共地 |

MAX98357A 模块需确认 SD_MODE/EN 的板上电阻配置与 GPIO 电压兼容。不要把此引脚硬接电源后再与 `pa_en` 相连。也可不接 `pa_en`，按模块说明设为常开。

PCM5102A 按模块说明设为 Philips I2S 和三线模式（需要时 SCK/MCLK 接地、XSMT 为有效电平）；`pa_en` 不接。并非所有成品模块都用同样跳线。PCM5102A 是线路输出，接有源音箱/后级功放；不能直接驱动低阻喇叭。

若使用外部 5 V 功放电源，须核对模块额定值并与 FPGA 共地，所有 FPGA 信号保持 3.3 V，不能将 5 V 输入 GPIO。MAX98357A 的喇叭接 SPK+ / SPK−，BTL 输出两端都不能接地。

## 12 路键盘

默认 TTP223 高有效输出，**3.3 V 供电**，各 OUT 接下表，各模块共地。未接的输入通过 CST 下拉为未按下。也可以用按下时接 3.3 V 的机械开关。默认消抖约 10 ms；不据此宣称整机控制延迟达标。

| key | 音符 | FPGA 球位 | Dock 接插件 |
| --- | --- | --- | --- |
| 0 | C4 | L2 | J3-3 |
| 1 | C#4 | L1 | J3-4 |
| 2 | D4 | K1 | J3-5 |
| 3 | D#4 | K2 | J3-6 |
| 4 | E4 | J4 | J3-7 |
| 5 | F4 | K4 | J3-8 |
| 6 | F#4 | L4 | J3-9 |
| 7 | G4 | L3 | J3-10 |
| 8 | G#4 | G2 | J3-11 |
| 9 | A4 | G1 | J3-12 |
| 10 | A#4 | G4 | J3-23 |
| 11 | B4 | H4 | J3-24 |

J3-1 提供 3.3 V，J3-2 为 GND。**J3-13 为 5 V，J3-14 为 GND，不是按键 IO。** 本方案占用 J3 SDRAM 扩展接口中的 IO，不能同时插用 SDRAM 模块。

## Dock 按键和状态灯

| 功能 | 球位 | 行为 |
| --- | --- | --- |
| S1 | H11 | 高有效，按住附加 C4；松开停止（若外部 key0 仍按住则继续） |
| S2 | H10 | 高有效，每按一次循环三角→方波→锯齿→脉冲→三角 |
| READY LED | E8 | 高电平点亮，任一声部占用时亮；tone_test 中上电复位结束后常亮 |

不使用 USB Host 的 L6/K6 作为 LED；它们接在 USB D+/D− 网络上。DONE LED 也不作为本设计端口。功放使能在有声部时拉高，空闲后保持约 155 ms 再拉低。

## 工程构建与下载

默认入口 `code/synth/build.ps1`：

```powershell
./code/synth/build.ps1 -Target tone_test -GenerateOnly
./code/synth/build.ps1 -Target synth_board12 -GowinHome 'D:/Gowin/你的安装目录'
```

脚本使用 `set_device` 设置 25K，加入 CST 与 `create_clock -period 20` 的 SDC，设置 `use_cpu_as_gpio`、`use_sspi_as_gpio`、`use_ready_as_gpio`。退出码失败、无新码流或旧码流残留均不会报告构建成功。不会自动触碰连接的设备。

GUI：打开板级目录下对应 `.gprj`，设顶层为 `primer25k_tone_top` 或 `primer25k_top`，确认 Device Version A；在 Place & Route → Dual-purpose pin 中开启 CPU/SSPI/READY 为普通 IO，再依次综合和布局布线。不要加入所有旧顶层文件，也不要导入 `code/constraints/` 的 Nano 约束。

先通过仿真，再本机 Gowin 构建并检查时序报告：50 MHz 时钟须满足，异步输入仅经过同步器，外部 DAC 输出还需根据模块时序和布线检查。当前 SDC 只给出系统时钟，并不代表 IO 时序已完整签核。

首次在 Programmer 选实际器件，SRAM Program 运行 `tone_test.fs`。预期听到约 440 Hz 方波，READY 亮。测量 BCLK≈3.125 MHz、LRCK≈48.828 kHz；无声时先查电源/共地/EN/I2S 格式，再接喇叭。通过后下载 synth_board12：上电静音，S1 发 C4，S2 切换音色，随后测试外部 12 键和三和弦。外部 Flash 写入方式参照官方介绍，不沿用 Nano 的 programmer 参数。

## 本次移植边界

本分支改的是板级适配、时钟与音准参数、构建/验证流程和文档，保留原有合成算法。原内核的音色幅度、包络/声部分配行为沿用原实现；本次仿真不是对全部音质、竞赛指标或模拟电路的认证。

## 核验来源

- [Sipeed 官方板卡介绍：器件、版本、Gowin 要求](https://wiki.sipeed.com/hardware/zh/tang/tang-primer-25k/primer-25k.html)
- [Dock 60033 官方原理图](https://dl.sipeed.com/fileList/TANG/Primer_25K/02_Schematic/Tang_Primer_25K_Dock_60033_Schematic.pdf)，第 1 页：J3/J6、S1/S2、READY、USB；第 2～3 页为调试器/USB
- [核心板 52300 官方原理图](https://dl.sipeed.com/fileList/TANG/Primer_25K/02_Schematic/Tang_Primer_25K_52300_Schematic.pdf)：50 MHz/E2 和器件球位
- [官方 PMOD 示例 CST](https://github.com/sipeed/TangPrimer-25K-example/blob/27c1737b687369f46baff9cf621cd7499a1b7fd4/pmod_led/src/pmod_led.cst)与 SDC、工程文件；此示例的 LED 定义不作为 USB 引脚可随意驱动的依据
- [Gowin Tcl 官方手册](https://cdn.gowinsemi.com.cn/SUG1220E.pdf)：set_device、READY/SSPI/CPU 双用途设置
