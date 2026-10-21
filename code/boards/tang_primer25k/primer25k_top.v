// Tang Primer 25K + Dock, 50 MHz, external 3.3 V I2S DAC/amplifier.
// S1 adds C4 while held; S2 cycles the four waveforms. External keys are
// active-high TTP223 outputs, C4..B4. READY LED indicates an active voice.
module primer25k_top #(
    parameter KEY_CNT_MAX = 500_000,
    parameter POR_CYCLES = 65_536,
    parameter PA_HOLD_CYCLES = 7_750_000
)(
    input wire clk,
    input wire button_play,
    input wire button_wave,
    input wire [11:0] key,
    output wire i2s_bck,
    output wire i2s_lrck,
    output wire i2s_din,
    output wire pa_en,
    output wire led_ready
);
    reg [31:0] por_count = 0;
    reg rst_n = 0;
    always @(posedge clk) begin
        if (por_count >= POR_CYCLES-1) rst_n <= 1'b1;
        else por_count <= por_count + 1'b1;
    end

    wire [11:0] keys = key | {11'b0, button_play};
    wire [11:0] key_state;
    wire note_valid, note_on;
    wire [4:0] note_idx;
    key_scan #(.KEY_NUM(12), .CNT_MAX(KEY_CNT_MAX), .ACTIVE_LOW(0)) u_keys (
        .clk(clk), .rst_n(rst_n), .key_in(keys), .key_state(key_state),
        .note_valid(note_valid), .note_on(note_on), .note_idx(note_idx)
    );

    wire wave_state, wave_press;
    debounce #(.CNT_MAX(KEY_CNT_MAX), .ACTIVE_LOW(0)) u_wave_key (
        .clk(clk), .rst_n(rst_n), .key_in(button_wave),
        .key_state(wave_state), .key_press(wave_press)
    );
    reg [1:0] wave_sel;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wave_sel <= 0;
        else if (wave_press) wave_sel <= wave_sel + 1'b1;
    end

    wire [3:0] voice_busy;
    wire signed [15:0] audio;
    synth_top #(.CLOCK_HZ(50_000_000), .BCK_HALF(8),
                .VOICE_NUM(4), .AMP(16'sh1800)) u_synth (
        .clk(clk), .rst_n(rst_n), .note_valid(note_valid),
        .note_on(note_on), .note_idx(note_idx), .wave_sel(wave_sel),
        .i2s_bck(i2s_bck), .i2s_lrck(i2s_lrck), .i2s_din(i2s_din),
        .dbg_voice_busy(voice_busy), .dbg_mix(audio)
    );

    // 155 ms at 50 MHz. Optional external MAX98357A SD_MODE connection.
    reg [31:0] pa_hold;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pa_hold <= 0;
        else if (|voice_busy) pa_hold <= PA_HOLD_CYCLES;
        else if (pa_hold != 0) pa_hold <= pa_hold - 1'b1;
    end
    assign pa_en = rst_n && (pa_hold != 0);
    assign led_ready = rst_n && (|voice_busy);
endmodule
