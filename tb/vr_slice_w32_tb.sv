`timescale 1ns/1ps

module vr_slice_w32_tb;
    vr_slice_tb_base #(
        .DATA_W(32),
        .SKID_EN(1),
        .DBG_EN(1),
        .TEST_GROUP(7),
        .ENABLE_SVA(1)
    ) tb();
endmodule
