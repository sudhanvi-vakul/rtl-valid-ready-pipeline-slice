`timescale 1ns/1ps

module vr_slice_flow_tb;
    vr_slice_tb_base #(
        .DATA_W(16),
        .SKID_EN(0),
        .DBG_EN(1),
        .TEST_GROUP(2),
        .ENABLE_SVA(1)
    ) tb();
endmodule
