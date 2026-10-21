// Independent 440 Hz square-wave bring-up, external I2S audio hardware.
module primer25k_tone_top #(
    parameter POR_CYCLES = 65_536
)(
    input wire clk,
    output wire i2s_bck, i2s_lrck, i2s_din, pa_en, led_ready
);
    reg [31:0] por_count = 0;
    reg rst_n = 0;
    always @(posedge clk) begin
        if (por_count >= POR_CYCLES-1) rst_n <= 1'b1;
        else por_count <= por_count + 1'b1;
    end
    wire sample_req;
    reg [31:0] phase;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) phase <= 0;
        else if (sample_req) phase <= phase + 32'd38702809;
    end
    wire [15:0] audio = phase[31] ? 16'h1800 : -16'h1800;
    i2s_tx #(.DATA_BITS(16), .BCK_HALF(8)) u_i2s (
        .clk(clk), .rst_n(rst_n), .sample_l(audio), .sample_r(audio),
        .bck(i2s_bck), .lrck(i2s_lrck), .din(i2s_din), .sample_req(sample_req)
    );
    assign pa_en = rst_n;
    assign led_ready = rst_n;
endmodule
