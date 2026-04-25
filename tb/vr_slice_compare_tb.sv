`timescale 1ns/1ps

module vr_slice_compare_tb;

    localparam integer DATA_W = 16;

    reg               clk;
    reg               rst_n;
    reg               in_valid;
    reg  [DATA_W-1:0] in_data;
    reg               out_ready;

    wire              in_ready_0;
    wire              out_valid_0;
    wire [DATA_W-1:0] out_data_0;
    wire              dbg_accept_0;
    wire              dbg_produce_0;
    wire              dbg_hold_0;
    wire              dbg_skid_active_0;
    wire [1:0]        dbg_occupancy_0;

    wire              in_ready_1;
    wire              out_valid_1;
    wire [DATA_W-1:0] out_data_1;
    wire              dbg_accept_1;
    wire              dbg_produce_1;
    wire              dbg_hold_1;
    wire              dbg_skid_active_1;
    wire [1:0]        dbg_occupancy_1;

    integer errors;
    integer i;

    vr_slice #(
        .DATA_W (DATA_W),
        .SKID_EN(0),
        .DBG_EN (1)
    ) dut_noskid (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       (in_valid),
        .in_ready       (in_ready_0),
        .in_data        (in_data),
        .out_valid      (out_valid_0),
        .out_ready      (out_ready),
        .out_data       (out_data_0),
        .dbg_accept     (dbg_accept_0),
        .dbg_produce    (dbg_produce_0),
        .dbg_hold       (dbg_hold_0),
        .dbg_skid_active(dbg_skid_active_0),
        .dbg_occupancy  (dbg_occupancy_0)
    );

    vr_slice #(
        .DATA_W (DATA_W),
        .SKID_EN(1),
        .DBG_EN (1)
    ) dut_skid (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       (in_valid),
        .in_ready       (in_ready_1),
        .in_data        (in_data),
        .out_valid      (out_valid_1),
        .out_ready      (out_ready),
        .out_data       (out_data_1),
        .dbg_accept     (dbg_accept_1),
        .dbg_produce    (dbg_produce_1),
        .dbg_hold       (dbg_hold_1),
        .dbg_skid_active(dbg_skid_active_1),
        .dbg_occupancy  (dbg_occupancy_1)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic apply_cycle;
        input bit iv;
        input [DATA_W-1:0] id;
        input bit ordy;
    begin
        @(negedge clk);
        in_valid  <= iv;
        in_data   <= id;
        out_ready <= ordy;
        @(posedge clk);
    end
    endtask

    task automatic compare_shared_state;
        input string label;
        begin
            // Do NOT compare in_ready or occupancy between skid and no-skid.
            // Skid buffer is expected to accept one extra item during backpressure.

            if (out_valid_0 !== out_valid_1) begin
                $error("TC32 %0s out_valid mismatch noskid=%0b skid=%0b",
                    label, out_valid_0, out_valid_1);
                errors = errors + 1;
            end

            if (out_valid_0 && out_valid_1 && (out_data_0 !== out_data_1)) begin
                $error("TC32 %0s out_data mismatch noskid=0x%0h skid=0x%0h",
                    label, out_data_0, out_data_1);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        rst_n     = 1'b0;
        in_valid  = 1'b0;
        in_data   = {DATA_W{1'b0}};
        out_ready = 1'b0;
        errors    = 0;

        $display("TC32 Skid On/Off Shared Scenario Comparison");

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        compare_shared_state("after reset");

        apply_cycle(1'b1, 'h201, 1'b1);
        compare_shared_state("beat 1 accepted");

        apply_cycle(1'b1, 'h202, 1'b1);
        compare_shared_state("beat 2 accepted");

        apply_cycle(1'b0, '0, 1'b0);
        compare_shared_state("empty or hold without new traffic");

        apply_cycle(1'b0, '0, 1'b0);
        compare_shared_state("stall without new input");

        apply_cycle(1'b0, '0, 1'b1);
        compare_shared_state("drain after stall");

        apply_cycle(1'b1, 'h210, 1'b1);
        compare_shared_state("mixed beat 0");

        apply_cycle(1'b0, '0, 1'b1);
        compare_shared_state("mixed bubble");

        apply_cycle(1'b1, 'h211, 1'b1);
        compare_shared_state("mixed beat 1");

        apply_cycle(1'b0, '0, 1'b0);
        compare_shared_state("mixed hold");

        apply_cycle(1'b0, '0, 1'b1);
        compare_shared_state("mixed drain");

        apply_cycle(1'b0, '0, 1'b1);
        compare_shared_state("final drain 1");
        apply_cycle(1'b0, '0, 1'b1);
        compare_shared_state("final drain 2");

        if (errors == 0) begin
            $display("[TB PASS] vr_slice_compare_tb");
            $finish;
        end else begin
            $display("[TB FAIL] vr_slice_compare_tb errors=%0d", errors);
            $fatal(1);
        end
    end

endmodule
