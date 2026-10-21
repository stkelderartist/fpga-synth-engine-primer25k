# 50 MHz crystal on E2. RTL uses clock enables; no generated fabric clocks.
create_clock -name clk_50m -period 20.000 -waveform {0 10} [get_ports {clk}]
# External key/button inputs pass through two-register synchronizers.
# DAC output timing still requires P&R review and measurement on hardware.
