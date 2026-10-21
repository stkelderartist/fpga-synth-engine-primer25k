`timescale 1ns/1ps
module tb_primer25k;
    reg clk = 0;
    always #10 clk = ~clk; // physical 50 MHz, no accelerated audio clock
    reg [11:0] key = 0;
    reg play = 0, wave_button = 0;
    wire bck, lrck, din, pa, led;
    primer25k_top #(.KEY_CNT_MAX(8), .POR_CYCLES(32),
                    .PA_HOLD_CYCLES(512)) dut (
        .clk(clk), .button_play(play), .button_wave(wave_button), .key(key),
        .i2s_bck(bck), .i2s_lrck(lrck), .i2s_din(din), .pa_en(pa), .led_ready(led)
    );
    wire tbck, tlrck, tdin, tpa, tled;
    primer25k_tone_top #(.POR_CYCLES(32)) tone (
        .clk(clk), .i2s_bck(tbck), .i2s_lrck(tlrck), .i2s_din(tdin),
        .pa_en(tpa), .led_ready(tled)
    );
    reg [4:0] idx = 0;
    wire [31:0] fcw;
    note_table #(.CLOCK_HZ(50_000_000),.BCK_HALF(8)) table25 (
        .note_idx(idx), .fcw(fcw)
    );
    integer errors = 0;
    integer i, n, crossings, last_bit, count_on;
    real freq, target, t0;
    reg [11:0] seen_on = 0;
    always @(posedge clk) if (dut.note_valid && dut.note_on) begin
        seen_on[dut.note_idx] <= 1'b1;
        count_on = count_on + 1;
    end
    task check;
        input condition;
        input [511:0] label_text;
        begin
            if (condition === 1'b1) $display("[PASS] %0s",label_text);
            else begin errors=errors+1; $display("[FAIL] %0s",label_text); end
        end
    endtask
    task cycles;
        input integer c;
        begin repeat(c) @(negedge clk); end
    endtask

    // Decode physical serial output on the DAC sampling edge. This checks
    // delay, stereo duplication, signed sample bit order and zero padding.
    reg [31:0] serial_l, serial_r;
    reg [15:0] expected;
    task read_tone_frame;
        begin
            @(negedge tlrck);
            expected = tone.audio;
            @(posedge tbck); #1; // I2S one-bit delay
            check(tdin === 0,"I2S delay bit is zero");
            serial_l = 0;
            for (n=0;n<31;n=n+1) begin
                @(posedge tbck); #1; serial_l = {serial_l[30:0],tdin};
            end
            @(posedge tbck); #1; // right delay bit
            check(tlrck === 1,"32 BCK per channel");
            serial_r = 0;
            for (n=0;n<31;n=n+1) begin
                @(posedge tbck); #1; serial_r = {serial_r[30:0],tdin};
            end
            check(serial_l[30:15] === expected,"decoded left sample matches square wave");
            check(serial_l === serial_r,"left and right samples match");
            check(serial_l[14:0] === 0,"16-bit PCM has zero padding");
        end
    endtask

    initial begin
        count_on=0;
        cycles(64);
        check(dut.rst_n && tone.rst_n,"power-on reset releases");
        check(dut.voice_busy === 0 && pa === 0 && led === 0,"boot is silent, external amp disabled");
        for (i=0;i<=24;i=i+1) begin
            idx=i; #1;
            target=440.0*(2.0**((i-9)/12.0));
            freq=fcw*48828.125/4294967296.0;
            check((freq-target < 0.00002) && (target-freq < 0.00002),"25-note tuning at 48.828125 kHz");
        end
        @(posedge bck); t0=$realtime;
        @(posedge bck); check($realtime-t0 == 320.0,"BCK is 3.125 MHz");
        @(posedge lrck); t0=$realtime;
        @(posedge lrck); check($realtime-t0 == 20480.0,"LRCK is 48.828125 kHz");
        read_tone_frame;
        read_tone_frame;

        // Count square-wave transitions over >20 ms of physical sample time.
        crossings=0; last_bit=tone.phase[31];
        repeat(1024) begin
            @(posedge tone.sample_req); @(negedge clk);
            if(tone.phase[31] != last_bit) crossings=crossings+1;
            last_bit=tone.phase[31];
        end
        check(crossings >= 18 && crossings <= 19,"440 Hz tone: correct transition count over 20.97 ms");

        key=12'h091; // C4 E4 G4 simultaneous
        cycles(120);
        check(dut.voice_busy === 4'b0111,"three simultaneous keys allocate three voices");
        cycles(50000);
        check(pa && led,"active chord enables amp and READY LED");
        check(dut.audio !== 16'sd0,"chord produces nonzero PCM");
        key=0; cycles(65000);
        check(dut.voice_busy === 0 && dut.audio === 0,"key release returns to silence");
        check(!pa && !led,"amp hold expires after release");
        for(i=0;i<12;i=i+1) begin
            key=(12'b1 << i); cycles(100); key=0; cycles(100);
        end
        check(seen_on === 12'hfff,"all 12 keys report their notes");
        play=1; cycles(100);
        check(dut.voice_busy === 4'b0001,"Dock S1 plays C4 without external keys");
        play=0; cycles(100);
        for(i=1;i<=4;i=i+1) begin
            wave_button=1; cycles(100); wave_button=0; cycles(100);
            check(dut.wave_sel === (i % 4),"Dock S2 cycles and wraps four waveforms");
        end
        if(errors) begin $display("[FAIL] primer25k errors=%0d",errors); $finish; end
        $display("[PASS] primer25k complete"); $finish;
    end
    initial begin #100000000; $display("[ERROR] primer25k timeout"); $finish; end
endmodule
