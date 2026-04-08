`timescale 1ns/1ps

module vr_slice_sva #(
    parameter integer DATA_W  = 16,
    parameter integer SKID_EN = 0
) (
    input wire              clk,
    input wire              rst_n,
    input wire              in_valid,
    input wire              in_ready,
    input wire [DATA_W-1:0] in_data,
    input wire              out_valid,
    input wire              out_ready,
    input wire [DATA_W-1:0] out_data,
    input wire [1:0]        dbg_occupancy
);

    property p_hold_valid_on_stall;
        @(posedge clk) disable iff (!rst_n)
            (out_valid && !out_ready) |=> out_valid;
    endproperty

    property p_hold_data_on_stall;
        @(posedge clk) disable iff (!rst_n)
            (out_valid && !out_ready) |=> $stable(out_data);
    endproperty

    property p_no_occupancy_overflow;
        @(posedge clk) disable iff (!rst_n)
            (SKID_EN != 0) ? (dbg_occupancy <= 2) : (dbg_occupancy <= 1);
    endproperty

    assert property (p_hold_valid_on_stall)
        else $error("ASSERT: out_valid dropped while stalled");

    assert property (p_hold_data_on_stall)
        else $error("ASSERT: out_data changed while stalled");

    assert property (p_no_occupancy_overflow)
        else $error("ASSERT: occupancy exceeded legal range");

endmodule
