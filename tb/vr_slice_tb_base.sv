`timescale 1ns/1ps

module vr_slice_tb_base #(
    parameter integer DATA_W       = 16,
    parameter integer SKID_EN      = 0,
    parameter integer DBG_EN       = 1,
    parameter integer TEST_GROUP   = 0,
    parameter integer ENABLE_SVA   = 1
);

    reg                  clk;
    reg                  rst_n;
    reg                  in_valid;
    wire                 in_ready;
    reg  [DATA_W-1:0]    in_data;
    wire                 out_valid;
    reg                  out_ready;
    wire [DATA_W-1:0]    out_data;

    wire                 dbg_accept;
    wire                 dbg_produce;
    wire                 dbg_hold;
    wire                 dbg_skid_active;
    wire [1:0]           dbg_occupancy;

    integer total_errors;
    integer testcase_errors;
    integer accept_count;
    integer produce_count;
    integer scoreboard_errors;
    integer cycle_count;
    integer i;
    reg [DATA_W-1:0]     hold_sample;

    reg [DATA_W-1:0] exp_q[$];
    reg [DATA_W-1:0] tmp_exp;
    reg [DATA_W-1:0] pat [0:5];

    vr_slice #(
        .DATA_W (DATA_W),
        .SKID_EN(SKID_EN),
        .DBG_EN (DBG_EN)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       (in_valid),
        .in_ready       (in_ready),
        .in_data        (in_data),
        .out_valid      (out_valid),
        .out_ready      (out_ready),
        .out_data       (out_data),
        .dbg_accept     (dbg_accept),
        .dbg_produce    (dbg_produce),
        .dbg_hold       (dbg_hold),
        .dbg_skid_active(dbg_skid_active),
        .dbg_occupancy  (dbg_occupancy)
    );

    generate
        if (ENABLE_SVA != 0) begin : g_sva
            vr_slice_sva #(
                .DATA_W (DATA_W),
                .SKID_EN(SKID_EN)
            ) sva_i (
                .clk         (clk),
                .rst_n       (rst_n),
                .in_valid    (in_valid),
                .in_ready    (in_ready),
                .in_data     (in_data),
                .out_valid   (out_valid),
                .out_ready   (out_ready),
                .out_data    (out_data),
                .dbg_occupancy(dbg_occupancy)
            );
        end
    endgenerate

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (!rst_n) begin
            exp_q.delete();
            accept_count     <= 0;
            produce_count    <= 0;
            scoreboard_errors <= 0;
        end else begin
            if (in_valid && in_ready) begin
                exp_q.push_back(in_data);
                accept_count <= accept_count + 1;
            end

            if (out_valid && out_ready) begin
                if (exp_q.size() == 0) begin
                    $error("Scoreboard underflow at cycle %0d", cycle_count);
                    scoreboard_errors <= scoreboard_errors + 1;
                end else begin
                    tmp_exp = exp_q[0];
                    exp_q.pop_front();
                    if (out_data !== tmp_exp) begin
                        $error("Scoreboard mismatch at cycle %0d expected=0x%0h got=0x%0h", cycle_count, tmp_exp, out_data);
                        scoreboard_errors <= scoreboard_errors + 1;
                    end
                end
                produce_count <= produce_count + 1;
            end
        end
    end

    task automatic clear_tracking;
    begin
        exp_q.delete();
        accept_count      = 0;
        produce_count     = 0;
        scoreboard_errors = 0;
        testcase_errors   = 0;
    end
    endtask

    task automatic check;
        input bit cond;
        input string msg;
    begin
        if (!cond) begin
            testcase_errors = testcase_errors + 1;
            total_errors    = total_errors + 1;
            $error("%0s", msg);
        end
    end
    endtask

    task automatic apply_cycle;
        input bit              iv;
        input [DATA_W-1:0]     id;
        input bit              ordy;
    begin
        @(negedge clk);
        in_valid  <= iv;
        in_data   <= id;
        out_ready <= ordy;
        @(posedge clk);
    end
    endtask

    task automatic hold_stall_cycles;
        input integer n;
        input [DATA_W-1:0] stable_data;
    begin
        hold_sample = stable_data;
        for (i = 0; i < n; i = i + 1) begin
            apply_cycle(1'b0, {DATA_W{1'b0}}, 1'b0);
            check(out_valid === 1'b1, "out_valid must remain high during stall");
            check(out_data === hold_sample, "out_data must remain stable during stall");
        end
    end
    endtask

    task automatic drain_cycles;
        input integer n;
    begin
        for (i = 0; i < n; i = i + 1) begin
            apply_cycle(1'b0, {DATA_W{1'b0}}, 1'b1);
        end
    end
    endtask

    task automatic expect_queue_empty;
    begin
        check(exp_q.size() == 0, "scoreboard queue must be empty");
        check(accept_count == produce_count, "accept_count must match produce_count");
        check(scoreboard_errors == 0, "scoreboard_errors must remain zero");
    end
    endtask

    task automatic reset_dut;
    begin
        @(negedge clk);
        rst_n     <= 1'b0;
        in_valid  <= 1'b0;
        in_data   <= {DATA_W{1'b0}};
        out_ready <= 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        clear_tracking();
    end
    endtask

    task automatic tc01_reset_default_state;
    begin
        $display("TC01 Reset Default State");
        reset_dut();
        check(out_valid === 1'b0, "reset must leave out_valid low");
        check(dbg_occupancy == 0, "reset must leave occupancy empty");
        check(in_ready === 1'b1, "reset release must leave slice ready for first beat");
    end
    endtask

    task automatic tc02_first_accept_into_empty_slice;
        reg [DATA_W-1:0] d;
    begin
        $display("TC02 First Accept Into Empty Slice");
        reset_dut();
        d = {{(DATA_W-8){1'b0}}, 8'hA5};
        apply_cycle(1'b1, d, 1'b0);
        check(out_valid === 1'b1, "first accepted beat must fill the slice");
        check(out_data  === d,    "stored data must match first accepted beat");
        check(accept_count == 1,  "accept_count must be 1 after first accept");
    end
    endtask

    task automatic tc03_first_output_transfer;
        reg [DATA_W-1:0] d;
    begin
        $display("TC03 First Output Transfer");
        reset_dut();
        d = {{(DATA_W-8){1'b0}}, 8'h3C};
        apply_cycle(1'b1, d, 1'b0);
        apply_cycle(1'b0, {DATA_W{1'b0}}, 1'b1);
        check(produce_count == 1, "first stored beat must be produced once");
        check(out_valid === 1'b0, "slice must drain back to empty");
        expect_queue_empty();
    end
    endtask

    task automatic tc04_hold_under_downstream_stall;
        reg [DATA_W-1:0] d;
    begin
        $display("TC04 Hold Under Downstream Stall");
        reset_dut();
        d = {{(DATA_W-8){1'b0}}, 8'h55};
        apply_cycle(1'b1, d, 1'b0);
        hold_stall_cycles(3, d);
        apply_cycle(1'b0, {DATA_W{1'b0}}, 1'b1);
        expect_queue_empty();
    end
    endtask

    task automatic tc05_drain_to_empty;
    begin
        $display("TC05 Drain To Empty");
        reset_dut();
        apply_cycle(1'b1, 'h11, 1'b0);
        apply_cycle(1'b0, '0, 1'b1);
        check(out_valid === 1'b0, "drain must return slice to empty");
        check(dbg_occupancy == 0, "occupancy must return to zero after drain");
        expect_queue_empty();
    end
    endtask

    task automatic tc06_bubble_then_refill;
    begin
        $display("TC06 Bubble Then Refill");
        reset_dut();
        apply_cycle(1'b1, 'h12, 1'b1);
        drain_cycles(1);
        apply_cycle(1'b0, '0, 1'b1);
        apply_cycle(1'b0, '0, 1'b1);
        check(out_valid === 1'b0, "empty bubble must show out_valid low");
        apply_cycle(1'b1, 'h34, 1'b0);
        check(out_valid === 1'b1, "refill after bubble must work");
        apply_cycle(1'b0, '0, 1'b1);
        expect_queue_empty();
    end
    endtask

    task automatic tc07_back_to_back_throughput;
    begin
        $display("TC07 Back-to-Back Throughput");
        reset_dut();
        for (i = 0; i < 6; i = i + 1) begin
            apply_cycle(1'b1, i + 1, 1'b1);
        end
        drain_cycles(2);
        check(accept_count == 6, "all six inputs must be accepted");
        check(produce_count == 6, "all six inputs must be produced");
        expect_queue_empty();
    end
    endtask

    task automatic tc08_alternating_input_valid;
    begin
        $display("TC08 Alternating Input Valid");
        reset_dut();
        apply_cycle(1'b1, 'h21, 1'b1);
        apply_cycle(1'b0, '0, 1'b1);
        apply_cycle(1'b1, 'h22, 1'b1);
        apply_cycle(1'b0, '0, 1'b1);
        apply_cycle(1'b1, 'h23, 1'b1);
        drain_cycles(2);
        check(accept_count == 3, "three valid pulses must be accepted");
        check(produce_count == 3, "three accepted beats must be produced");
        expect_queue_empty();
    end
    endtask

    task automatic tc09_alternating_output_ready;
    begin
        $display("TC09 Alternating Output Ready");
        reset_dut();
        for (i = 0; i < 5; i = i + 1) begin
            apply_cycle(1'b1, i + 'h30, (i % 2) == 0);
        end
        drain_cycles(6);
        check(accept_count == 5, "all five inputs must eventually be accepted");
        check(produce_count == 5, "all five inputs must eventually be produced");
        expect_queue_empty();
    end
    endtask

    task automatic tc10_simultaneous_consume_and_refill;
    begin
        $display("TC10 Simultaneous Consume And Refill");
        reset_dut();
        apply_cycle(1'b1, 'h41, 1'b0);
        apply_cycle(1'b1, 'h42, 1'b1);
        check(out_valid === 1'b1, "slice must remain occupied after consume+refill");
        check(out_data  === 'h42, "new beat must refill the main slot");
        apply_cycle(1'b0, '0, 1'b1);
        expect_queue_empty();
    end
    endtask

    task automatic tc11_long_burst_transfer;
    begin
        $display("TC11 Long Burst Transfer");
        reset_dut();
        for (i = 0; i < 20; i = i + 1) begin
            apply_cycle(1'b1, i + 'h50, 1'b1);
        end
        drain_cycles(2);
        check(accept_count == 20, "20-beat burst must be accepted");
        check(produce_count == 20, "20-beat burst must be produced");
        expect_queue_empty();
    end
    endtask

    task automatic tc12_output_idle_behavior_while_empty;
    begin
        $display("TC12 Output Idle Behavior While Empty");
        reset_dut();
        apply_cycle(1'b0, '0, 1'b0);
        check(out_valid === 1'b0, "out_valid must stay low while empty");
        apply_cycle(1'b0, '0, 1'b1);
        check(out_valid === 1'b0, "out_valid must stay low while empty even when ready toggles");
        check(produce_count == 0, "no outputs may be produced while empty");
    end
    endtask

    task automatic tc13_input_blocking_when_full_and_stalled;
        reg [DATA_W-1:0] d0;
        reg [DATA_W-1:0] d1;
    begin
        $display("TC13 Input Blocking When Full And Stalled");
        reset_dut();
        d0 = 'h61;
        d1 = 'h62;
        apply_cycle(1'b1, d0, 1'b0);
        apply_cycle(1'b1, d1, 1'b0);
        if (SKID_EN == 0) begin
            check(accept_count == 1, "baseline mode must block second beat while stalled");
            check(out_data === d0,   "first beat must remain resident");
        end else begin
            check(accept_count == 2, "skid mode may absorb one extra beat");
            check(dbg_occupancy == 2, "skid mode must show occupancy 2 after extra capture");
        end
    end
    endtask

    task automatic tc14_repeated_same_payload_values;
    begin
        $display("TC14 Repeated Same Payload Values");
        reset_dut();
        for (i = 0; i < 4; i = i + 1) begin
            apply_cycle(1'b1, 'h77, 1'b1);
        end
        drain_cycles(2);
        check(accept_count == 4, "repeated equal payloads must still count as unique transfers");
        check(produce_count == 4, "repeated equal payloads must all be produced");
        expect_queue_empty();
    end
    endtask

    task automatic tc15_corner_data_patterns;
    begin
        $display("TC15 Corner Data Patterns");
        reset_dut();
        pat[0] = {DATA_W{1'b0}};
        pat[1] = {DATA_W{1'b1}};
        pat[2] = {{(DATA_W+1)/2{2'b10}}};
        pat[3] = {{(DATA_W+1)/2{2'b01}}};
        pat[4] = {{1'b1}, {DATA_W-1{1'b0}}};
        pat[5] = {{DATA_W-1{1'b0}}, 1'b1};
        for (i = 0; i < 6; i = i + 1) begin
            apply_cycle(1'b1, pat[i], 1'b1);
        end
        drain_cycles(2);
        check(accept_count == 6, "all corner patterns must be accepted");
        check(produce_count == 6, "all corner patterns must be produced");
        expect_queue_empty();
    end
    endtask

    task automatic tc16_random_valid_ready_throttling;
        reg [DATA_W-1:0] next_data;
    begin
        $display("TC16 Random Valid/Ready Throttling");
        reset_dut();
        next_data = 'h80;
        for (i = 0; i < 80; i = i + 1) begin
            apply_cycle($urandom_range(0,1), next_data, $urandom_range(0,1));
            if (in_valid && in_ready) begin
                next_data = next_data + 1;
            end
        end
        drain_cycles(20);
        expect_queue_empty();
    end
    endtask

    task automatic tc17_long_stall_with_persistent_upstream_requests;
        reg [DATA_W-1:0] d0;
    begin
        $display("TC17 Long Stall With Persistent Upstream Requests");
        reset_dut();
        d0 = 'h91;
        apply_cycle(1'b1, d0, 1'b0);
        for (i = 0; i < 6; i = i + 1) begin
            apply_cycle(1'b1, d0 + i + 1, 1'b0);
        end
        if (SKID_EN == 0) begin
            check(accept_count == 1, "baseline mode must not keep accepting while stalled");
        end else begin
            check(accept_count == 2, "skid mode may hold only one extra beat under sustained stall");
        end
        drain_cycles(6);
        if (SKID_EN == 0) begin
            check(produce_count == 1, "baseline mode must only produce the first stalled beat");
        end else begin
            check(produce_count == 2, "skid mode must produce two stored beats");
        end
        expect_queue_empty();
    end
    endtask

    task automatic tc18_random_burst_length_sweep;
        integer burst_len;
        integer beat_idx;
        reg [DATA_W-1:0] next_data;
    begin
        $display("TC18 Random Burst Length Sweep");
        reset_dut();
        next_data = 'hA0;
        for (i = 0; i < 8; i = i + 1) begin
            burst_len = $urandom_range(1, 5);
            for (beat_idx = 0; beat_idx < burst_len; beat_idx = beat_idx + 1) begin
                apply_cycle(1'b1, next_data, $urandom_range(0,1));
                if (in_valid && in_ready) begin
                    next_data = next_data + 1;
                end
            end
            apply_cycle(1'b0, '0, $urandom_range(0,1));
            apply_cycle(1'b0, '0, $urandom_range(0,1));
        end
        drain_cycles(20);
        expect_queue_empty();
    end
    endtask

    task automatic tc19_reset_during_held_valid;
    begin
        $display("TC19 Reset During Held Valid");
        reset_dut();
        apply_cycle(1'b1, 'hB1, 1'b0);
        hold_stall_cycles(2, 'hB1);
        @(negedge clk);
        rst_n     <= 1'b0;
        in_valid  <= 1'b0;
        out_ready <= 1'b0;
        @(posedge clk);
        check(out_valid === 1'b0, "reset must flush held valid data");
        @(negedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        clear_tracking();
        check(out_valid === 1'b0, "post-reset state must be empty");
    end
    endtask

    task automatic tc20_reset_during_streaming_traffic;
    begin
        $display("TC20 Reset During Streaming Traffic");
        reset_dut();
        apply_cycle(1'b1, 'hC1, 1'b1);
        apply_cycle(1'b1, 'hC2, 1'b1);
        @(negedge clk);
        rst_n     <= 1'b0;
        in_valid  <= 1'b0;
        out_ready <= 1'b0;
        @(posedge clk);
        check(out_valid === 1'b0, "mid-stream reset must clear visible output");
        @(negedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        clear_tracking();
        apply_cycle(1'b1, 'hC3, 1'b1);
        drain_cycles(2);
        expect_queue_empty();
    end
    endtask

    task automatic tc21_recovery_immediately_after_reset;
    begin
        $display("TC21 Recovery Immediately After Reset");
        reset_dut();
        apply_cycle(1'b1, 'hD1, 1'b1);
        drain_cycles(2);
        expect_queue_empty();
    end
    endtask

    task automatic tc22_transfer_count_accounting;
    begin
        $display("TC22 Transfer Count Accounting");
        reset_dut();
        for (i = 0; i < 12; i = i + 1) begin
            apply_cycle(1'b1, i + 'hE0, (i % 3) != 1);
        end
        drain_cycles(12);
        check(accept_count == produce_count, "accepted and produced counts must match at end of drain");
        expect_queue_empty();
    end
    endtask

    task automatic tc23_assertion_stress_run;
        reg [DATA_W-1:0] next_data;
    begin
        $display("TC23 Assertion Stress Run");
        reset_dut();
        next_data = 'hF0;
        for (i = 0; i < 120; i = i + 1) begin
            apply_cycle($urandom_range(0,1), next_data, $urandom_range(0,1));
            if (in_valid && in_ready) begin
                next_data = next_data + 1;
            end
        end
        drain_cycles(24);
        expect_queue_empty();
    end
    endtask

    task automatic tc24_skid_disabled_reference_behavior;
    begin
        $display("TC24 Skid Disabled Reference Behavior");
        reset_dut();
        check(SKID_EN == 0, "TC24 must run with SKID_EN=0");
        apply_cycle(1'b1, 'h111, 1'b0);
        apply_cycle(1'b1, 'h112, 1'b0);
        check(accept_count == 1, "skid disabled reference must block the second beat");
        apply_cycle(1'b0, '0, 1'b1);
        expect_queue_empty();
    end
    endtask

    task automatic tc25_skid_single_extra_capture;
    begin
        $display("TC25 Skid Single Extra Capture");
        reset_dut();
        check(SKID_EN != 0, "TC25 must run with SKID_EN=1");
        apply_cycle(1'b1, 'h121, 1'b0);
        apply_cycle(1'b1, 'h122, 1'b0);
        check(accept_count == 2, "skid mode must capture one extra beat");
        check(dbg_skid_active === 1'b1, "skid must become active after extra capture");
        check(dbg_occupancy == 2, "occupancy must show two buffered beats");
        drain_cycles(3);
        expect_queue_empty();
    end
    endtask

    task automatic tc26_skid_hold_and_drain_ordering;
    begin
        $display("TC26 Skid Hold And Drain Ordering");
        reset_dut();
        check(SKID_EN != 0, "TC26 must run with SKID_EN=1");
        apply_cycle(1'b1, 'h131, 1'b0);
        apply_cycle(1'b1, 'h132, 1'b0);
        apply_cycle(1'b0, '0, 1'b1);
        check(out_valid === 1'b1, "after draining main, skid data must advance to main");
        check(out_data  === 'h132, "second accepted beat must appear after main drains");
        apply_cycle(1'b0, '0, 1'b1);
        expect_queue_empty();
    end
    endtask

    task automatic tc27_skid_with_repeated_backpressure_pulses;
    begin
        $display("TC27 Skid With Repeated Backpressure Pulses");
        reset_dut();
        check(SKID_EN != 0, "TC27 must run with SKID_EN=1");
        apply_cycle(1'b1, 'h141, 1'b0);
        apply_cycle(1'b1, 'h142, 1'b0);
        apply_cycle(1'b0, '0, 1'b1);
        apply_cycle(1'b1, 'h143, 1'b0);
        apply_cycle(1'b1, 'h144, 1'b0);
        drain_cycles(6);
        check(produce_count >= 3, "repeated backpressure pulses must still preserve data");
        expect_queue_empty();
    end
    endtask

    task automatic tc28_skid_random_traffic_stress;
        reg [DATA_W-1:0] next_data;
    begin
        $display("TC28 Skid Random Traffic Stress");
        reset_dut();
        check(SKID_EN != 0, "TC28 must run with SKID_EN=1");
        next_data = 'h150;
        for (i = 0; i < 120; i = i + 1) begin
            apply_cycle($urandom_range(0,1), next_data, $urandom_range(0,1));
            if (in_valid && in_ready) begin
                next_data = next_data + 1;
            end
        end
        drain_cycles(30);
        expect_queue_empty();
    end
    endtask

    task automatic tc29_width_8_sanity;
    begin
        $display("TC29 DATA_W = 8 Sanity Run");
        reset_dut();
        check(DATA_W == 8, "TC29 must run with DATA_W=8");
        apply_cycle(1'b1, 8'hA1, 1'b1);
        apply_cycle(1'b1, 8'h5C, 1'b1);
        drain_cycles(2);
        expect_queue_empty();
    end
    endtask

    task automatic tc30_width_32_sanity;
    begin
        $display("TC30 DATA_W = 32 Sanity Run");
        reset_dut();
        check(DATA_W == 32, "TC30 must run with DATA_W=32");
        apply_cycle(1'b1, 32'hDEADBEEF, 1'b1);
        apply_cycle(1'b1, 32'h12345678, 1'b1);
        drain_cycles(2);
        expect_queue_empty();
    end
    endtask

    task automatic tc31_debug_signal_consistency;
    begin
        $display("TC31 Occupancy / Debug Signal Consistency");
        reset_dut();
        apply_cycle(1'b1, 'h161, 1'b0);
        check(dbg_occupancy == 1,   "occupancy must be 1 after first accept");
        apply_cycle(1'b0, '0, 1'b0);
        check(dbg_hold === 1'b1,    "dbg_hold must assert while main entry is stalled");
        if (SKID_EN != 0) begin
            apply_cycle(1'b1, 'h162, 1'b0);
            check(dbg_skid_active === 1'b1, "dbg_skid_active must assert when skid entry is occupied");
            check(dbg_occupancy == 2,       "occupancy must be 2 when main + skid are full");
        end
        apply_cycle(1'b0, '0, 1'b1);
        if (SKID_EN != 0) begin
            check(dbg_occupancy == 1, "one skid-captured beat must remain after first drain");
        end else begin
            check(dbg_occupancy == 0, "baseline mode must drain back to empty");
        end
    end
    endtask

    task automatic finish_group;
        input string group_name;
    begin
        if (testcase_errors == 0) begin
            $display("[PASS] %0s", group_name);
        end else begin
            $display("[FAIL] %0s errors=%0d", group_name, testcase_errors);
        end
    end
    endtask

    initial begin
        rst_n          = 1'b0;
        in_valid       = 1'b0;
        in_data        = {DATA_W{1'b0}};
        out_ready      = 1'b0;
        total_errors   = 0;
        testcase_errors= 0;
        accept_count   = 0;
        produce_count  = 0;
        scoreboard_errors = 0;
        cycle_count    = 0;

        repeat (2) @(posedge clk);

        case (TEST_GROUP)
            1: begin
                tc01_reset_default_state();
                tc02_first_accept_into_empty_slice();
                tc03_first_output_transfer();
                finish_group("smoke");
            end

            2: begin
                tc04_hold_under_downstream_stall();
                tc05_drain_to_empty();
                tc06_bubble_then_refill();
                tc07_back_to_back_throughput();
                tc08_alternating_input_valid();
                tc09_alternating_output_ready();
                tc10_simultaneous_consume_and_refill();
                tc11_long_burst_transfer();
                tc12_output_idle_behavior_while_empty();
                tc13_input_blocking_when_full_and_stalled();
                tc14_repeated_same_payload_values();
                tc15_corner_data_patterns();
                finish_group("flow");
            end

            3: begin
                tc16_random_valid_ready_throttling();
                tc17_long_stall_with_persistent_upstream_requests();
                tc18_random_burst_length_sweep();
                tc19_reset_during_held_valid();
                tc20_reset_during_streaming_traffic();
                tc21_recovery_immediately_after_reset();
                tc22_transfer_count_accounting();
                tc23_assertion_stress_run();
                finish_group("stress");
            end

            4: begin
                tc24_skid_disabled_reference_behavior();
                finish_group("noskid_ref");
            end

            5: begin
                tc25_skid_single_extra_capture();
                tc26_skid_hold_and_drain_ordering();
                tc27_skid_with_repeated_backpressure_pulses();
                tc28_skid_random_traffic_stress();
                finish_group("skid");
            end

            6: begin
                tc29_width_8_sanity();
                finish_group("width8");
            end

            7: begin
                tc30_width_32_sanity();
                finish_group("width32");
            end

            8: begin
                tc31_debug_signal_consistency();
                finish_group("debug");
            end

            900: begin
                tc01_reset_default_state();
                tc02_first_accept_into_empty_slice();
                tc03_first_output_transfer();
                tc04_hold_under_downstream_stall();
                tc07_back_to_back_throughput();
                tc10_simultaneous_consume_and_refill();
                tc16_random_valid_ready_throttling();
                if (SKID_EN != 0) begin
                    tc25_skid_single_extra_capture();
                    tc26_skid_hold_and_drain_ordering();
                    tc31_debug_signal_consistency();
                end
                finish_group("integrated");
            end

            default: begin
                $error("Unsupported TEST_GROUP=%0d", TEST_GROUP);
                total_errors = total_errors + 1;
            end
        endcase

        if ((testcase_errors == 0) && (total_errors == 0)) begin
            $display("[TB PASS] vr_slice_tb_base DATA_W=%0d SKID_EN=%0d TEST_GROUP=%0d", DATA_W, SKID_EN, TEST_GROUP);
            $finish;
        end else begin
            $display("[TB FAIL] vr_slice_tb_base DATA_W=%0d SKID_EN=%0d TEST_GROUP=%0d total_errors=%0d testcase_errors=%0d",
                     DATA_W, SKID_EN, TEST_GROUP, total_errors, testcase_errors);
            $fatal(1);
        end
    end

endmodule
