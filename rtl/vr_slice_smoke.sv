`timescale 1ns/1ps

module vr_slice #(
    parameter int DATA_W  = 32,
    parameter bit SKID_EN = 1'b0
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              in_valid,
    output logic              in_ready,
    input  logic [DATA_W-1:0] in_data,
    output logic              out_valid,
    input  logic              out_ready,
    output logic [DATA_W-1:0] out_data
);

    localparam int DEPTH = (SKID_EN) ? 2 : 1;

    // Main stage entry (oldest item presented downstream)
    logic              full_q;
    logic [DATA_W-1:0] data_q;

    // Optional skid entry (second item, only used when SKID_EN=1)
    logic              skid_valid_q;
    logic [DATA_W-1:0] skid_data_q;

    logic [1:0] occupancy;
    logic       pop;
    logic       push;

    logic              full_n;
    logic [DATA_W-1:0] data_n;
    logic              skid_valid_n;
    logic [DATA_W-1:0] skid_data_n;

    always_comb begin
        occupancy = 2'(full_q) + 2'(skid_valid_q);

        out_valid = full_q;
        out_data  = data_q;

        pop      = out_valid && out_ready;
        in_ready = (occupancy < DEPTH) || pop;
        push     = in_valid && in_ready;

        // Default hold state.
        full_n       = full_q;
        data_n       = data_q;
        skid_valid_n = (SKID_EN) ? skid_valid_q : 1'b0;
        skid_data_n  = skid_data_q;

        // Step 1: remove oldest entry if downstream consumes it.
        if (pop) begin
            if (SKID_EN && skid_valid_q) begin
                full_n       = 1'b1;
                data_n       = skid_data_q;
                skid_valid_n = 1'b0;
            end else begin
                full_n       = 1'b0;
                skid_valid_n = 1'b0;
            end
        end

        // Step 2: append a newly accepted entry to the tail.
        if (push) begin
            if (!full_n) begin
                full_n = 1'b1;
                data_n = in_data;
            end else if (SKID_EN && !skid_valid_n) begin
                skid_valid_n = 1'b1;
                skid_data_n  = in_data;
            end
        end

        // Keep unused skid data deterministic in non-skid mode.
        if (!SKID_EN) begin
            skid_valid_n = 1'b0;
            skid_data_n  = '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full_q       <= 1'b0;
            data_q       <= '0;
            skid_valid_q <= 1'b0;
            skid_data_q  <= '0;
        end else begin
            full_q       <= full_n;
            data_q       <= data_n;
            skid_valid_q <= skid_valid_n;
            skid_data_q  <= skid_data_n;
        end
    end

endmodule
