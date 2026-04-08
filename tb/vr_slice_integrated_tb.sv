`timescale 1ns/1ps

module vr_slice_integrated_tb;

    localparam int DATA_W      = 8;
    localparam bit TB_SKID_EN  = 1'b0; // Set to 1 to run skid-mode scenarios as well.
    localparam int CLK_PERIOD  = 10;
    localparam int RANDOM_CYC  = 200;

    logic              clk;
    logic              rst_n;
    logic              in_valid;
    logic              in_ready;
    logic [DATA_W-1:0] in_data;
    logic              out_valid;
    logic              out_ready;
    logic [DATA_W-1:0] out_data;

    vr_slice #(
        .DATA_W (DATA_W),
        .SKID_EN(TB_SKID_EN)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .in_ready (in_ready),
        .in_data  (in_data),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_data (out_data)
    );

    logic [DATA_W-1:0] exp_q[$];
    logic [DATA_W-1:0] stall_data_prev;
    bit                stall_active_prev;

    int accepted_total;
    int produced_total;
    int mismatch_count;
    int assertion_fail_count;
    int tests_run;
    int tests_failed;
    int cycles;

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ------------------------------------------------------------
    // Scoreboard / protocol checks
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_q.delete();
            stall_active_prev    <= 1'b0;
            stall_data_prev      <= '0;
        end else begin
            if (in_valid && in_ready) begin
                exp_q.push_back(in_data);
                accepted_total <= accepted_total + 1;
            end

            if (out_valid && out_ready) begin
                if (exp_q.size() == 0) begin
                    $error("Ghost output transfer detected: out_data=0x%0h", out_data);
                    mismatch_count <= mismatch_count + 1;
                end else begin
                    logic [DATA_W-1:0] exp;
                    exp = exp_q.pop_front();
                    if (out_data !== exp) begin
                        $error("Scoreboard mismatch: expected=0x%0h got=0x%0h", exp, out_data);
                        mismatch_count <= mismatch_count + 1;
                    end
                end
                produced_total <= produced_total + 1;
            end

            if (stall_active_prev) begin
                if (!out_valid) begin
                    $error("Protocol failure: out_valid dropped during stall");
                    assertion_fail_count <= assertion_fail_count + 1;
                end
                if (out_data !== stall_data_prev) begin
                    $error("Protocol failure: out_data changed during stall. prev=0x%0h now=0x%0h",
                           stall_data_prev, out_data);
                    assertion_fail_count <= assertion_fail_count + 1;
                end
            end

            stall_active_prev <= out_valid && !out_ready;
            stall_data_prev   <= out_data;
        end
    end

    always @(posedge clk) begin
        cycles <= cycles + 1;
        if (cycles > 5000) begin
            $fatal(1, "Simulation timeout");
        end
    end

    // ------------------------------------------------------------
    // Utility tasks
    // ------------------------------------------------------------
    task automatic clear_inputs();
        begin
            in_valid  = 1'b0;
            in_data   = '0;
            out_ready = 1'b0;
        end
    endtask

    task automatic tick(input int n);
        begin
            repeat (n) @(posedge clk);
        end
    endtask

    task automatic apply_reset();
        begin
            clear_inputs();
            rst_n = 1'b0;
            tick(3);
            rst_n = 1'b1;
            tick(2);
        end
    endtask

    task automatic ensure_queue_empty(input string where_);
        begin
            if (exp_q.size() != 0) begin
                $error("Expected empty scoreboard queue at %s, size=%0d", where_, exp_q.size());
                mismatch_count = mismatch_count + 1;
            end
        end
    endtask

    task automatic push_one(input logic [DATA_W-1:0] data);
        begin
            in_data  = data;
            in_valid = 1'b1;
            do begin
                @(negedge clk);
            end while (!in_ready || !rst_n);
            @(posedge clk);
            @(negedge clk);
            in_valid = 1'b0;
            in_data  = '0;
        end
    endtask

    task automatic push_burst(input int count, input int base);
        int i;
        begin
            for (i = 0; i < count; i++) begin
                push_one(base + i);
            end
        end
    endtask

    task automatic consume_cycles(input int n);
        begin
            out_ready = 1'b1;
            tick(n);
            out_ready = 1'b0;
        end
    endtask

    task automatic drain_all();
        int guard;
        begin
            out_ready = 1'b1;
            guard = 0;
            while (exp_q.size() != 0 && guard < 64) begin
                tick(1);
                guard++;
            end
            out_ready = 1'b0;
            if (exp_q.size() != 0) begin
                $error("Drain failed: scoreboard still holds %0d entries", exp_q.size());
                mismatch_count = mismatch_count + 1;
            end
        end
    endtask

    task automatic start_test(input string name);
        begin
            tests_run = tests_run + 1;
            $display("\n============================================================");
            $display("%s", name);
            $display("============================================================");
        end
    endtask

    task automatic finish_test(input string name, input int err_before, input int asrt_before);
        int new_errs;
        begin
            new_errs = (mismatch_count - err_before) + (assertion_fail_count - asrt_before);
            if (new_errs == 0) begin
                $display("%s : PASS", name);
            end else begin
                $display("%s : FAIL (%0d new issue(s))", name, new_errs);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Individual testcases
    // ------------------------------------------------------------
    task automatic tc01_reset_default_state();
        int e0, a0;
        begin
            start_test("TC01 Reset Default State");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            if (out_valid !== 1'b0) begin
                $error("Reset check failed: out_valid should be 0 after reset");
                mismatch_count = mismatch_count + 1;
            end
            if (in_ready !== 1'b1) begin
                $error("Reset check failed: in_ready should be 1 when slice is empty");
                mismatch_count = mismatch_count + 1;
            end
            if (dut.full_q !== 1'b0) begin
                $error("Reset check failed: full_q should be 0");
                mismatch_count = mismatch_count + 1;
            end
            finish_test("TC01 Reset Default State", e0, a0);
        end
    endtask

    task automatic tc02_first_accept_into_empty();
        int e0, a0;
        begin
            start_test("TC02 First Accept Into Empty Slice");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'hA5);
            tick(1);
            if (!out_valid || out_data !== 8'hA5) begin
                $error("First accept failed: expected held payload 0xA5");
                mismatch_count = mismatch_count + 1;
            end
            finish_test("TC02 First Accept Into Empty Slice", e0, a0);
        end
    endtask

    task automatic tc03_first_output_transfer();
        int e0, a0;
        begin
            start_test("TC03 First Output Transfer");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'h11);
            tick(1);
            consume_cycles(2);
            tick(1);
            if (out_valid !== 1'b0) begin
                $error("Stage should be empty after single drain");
                mismatch_count = mismatch_count + 1;
            end
            ensure_queue_empty("TC03");
            finish_test("TC03 First Output Transfer", e0, a0);
        end
    endtask

    task automatic tc04_hold_under_downstream_stall();
        int e0, a0;
        begin
            start_test("TC04 Hold Under Downstream Stall");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'hC3);
            tick(5);
            if (!out_valid || out_data !== 8'hC3) begin
                $error("Hold-under-stall failed: expected payload to remain visible");
                mismatch_count = mismatch_count + 1;
            end
            drain_all();
            finish_test("TC04 Hold Under Downstream Stall", e0, a0);
        end
    endtask

    task automatic tc05_drain_to_empty();
        int e0, a0;
        begin
            start_test("TC05 Drain To Empty");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'h33);
            drain_all();
            tick(1);
            if (out_valid !== 1'b0) begin
                $error("Drain-to-empty failed: out_valid should drop after final transfer");
                mismatch_count = mismatch_count + 1;
            end
            finish_test("TC05 Drain To Empty", e0, a0);
        end
    endtask

    task automatic tc06_bubble_then_refill();
        int e0, a0;
        begin
            start_test("TC06 Bubble Then Refill");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            push_one(8'h44);
            drain_all();
            tick(2);
            if (out_valid !== 1'b0) begin
                $error("Bubble check failed: stage should be empty before refill");
                mismatch_count = mismatch_count + 1;
            end
            out_ready = 1'b0;
            push_one(8'h55);
            tick(1);
            if (!out_valid || out_data !== 8'h55) begin
                $error("Refill failed after bubble");
                mismatch_count = mismatch_count + 1;
            end
            drain_all();
            finish_test("TC06 Bubble Then Refill", e0, a0);
        end
    endtask

    task automatic tc07_back_to_back_throughput();
        int e0, a0;
        int i;
        begin
            start_test("TC07 Back-to-Back Throughput");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            for (i = 0; i < 8; i++) begin
                in_valid = 1'b1;
                in_data  = 8'h60 + i;
                tick(1);
            end
            in_valid  = 1'b0;
            in_data   = '0;
            tick(4);
            out_ready = 1'b0;
            ensure_queue_empty("TC07");
            finish_test("TC07 Back-to-Back Throughput", e0, a0);
        end
    endtask

    task automatic tc08_alternating_input_valid();
        int e0, a0;
        int i;
        begin
            start_test("TC08 Alternating Input Valid");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            for (i = 0; i < 10; i++) begin
                in_valid = i[0];
                in_data  = 8'h80 + i;
                tick(1);
            end
            in_valid  = 1'b0;
            out_ready = 1'b1;
            tick(4);
            out_ready = 1'b0;
            ensure_queue_empty("TC08");
            finish_test("TC08 Alternating Input Valid", e0, a0);
        end
    endtask

    task automatic tc09_alternating_output_ready();
        int e0, a0;
        int i;
        begin
            start_test("TC09 Alternating Output Ready");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            fork
                push_burst(8, 8'h90);
                begin
                    for (i = 0; i < 20; i++) begin
                        out_ready = ~i[0];
                        tick(1);
                    end
                    out_ready = 1'b0;
                end
            join
            drain_all();
            finish_test("TC09 Alternating Output Ready", e0, a0);
        end
    endtask

    task automatic tc10_simultaneous_consume_and_refill();
        int e0, a0;
        begin
            start_test("TC10 Simultaneous Consume And Refill");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'hA0);
            @(negedge clk);
            out_ready = 1'b1;
            in_valid  = 1'b1;
            in_data   = 8'hA1;
            @(posedge clk);
            @(negedge clk);
            in_valid  = 1'b0;
            out_ready = 1'b0;
            tick(1);
            if (!out_valid || out_data !== 8'hA1) begin
                $error("Consume+refill failed: expected new payload to remain resident");
                mismatch_count = mismatch_count + 1;
            end
            drain_all();
            finish_test("TC10 Simultaneous Consume And Refill", e0, a0);
        end
    endtask

    task automatic tc11_long_burst_transfer();
        int e0, a0;
        begin
            start_test("TC11 Long Burst Transfer");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            push_burst(20, 8'h10);
            tick(8);
            out_ready = 1'b0;
            ensure_queue_empty("TC11");
            finish_test("TC11 Long Burst Transfer", e0, a0);
        end
    endtask

    task automatic tc12_output_idle_behavior_while_empty();
        int e0, a0;
        begin
            start_test("TC12 Output Idle Behavior While Empty");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            tick(5);
            if (out_valid !== 1'b0) begin
                $error("Empty-idle failure: out_valid should stay low while empty");
                mismatch_count = mismatch_count + 1;
            end
            finish_test("TC12 Output Idle Behavior While Empty", e0, a0);
        end
    endtask

    task automatic tc13_input_blocking_when_full_and_stalled();
        int e0, a0;
        begin
            start_test("TC13 Input Blocking When Full And Stalled");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'hB0);
            tick(1);
            if (TB_SKID_EN) begin
                // In skid mode, one extra capture is legal.
                @(negedge clk);
                in_valid = 1'b1;
                in_data  = 8'hB1;
                tick(1);
                if (in_ready !== 1'b0) begin
                    $error("Skid mode should be full after the extra capture");
                    mismatch_count = mismatch_count + 1;
                end
                @(negedge clk);
                in_valid = 1'b0;
            end else begin
                if (in_ready !== 1'b0) begin
                    $error("Baseline mode should block input while full and stalled");
                    mismatch_count = mismatch_count + 1;
                end
            end
            drain_all();
            finish_test("TC13 Input Blocking When Full And Stalled", e0, a0);
        end
    endtask

    task automatic tc14_repeated_same_payload_values();
        int e0, a0;
        int i;
        begin
            start_test("TC14 Repeated Same Payload Values");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            for (i = 0; i < 8; i++) begin
                push_one(8'h5A);
            end
            tick(4);
            out_ready = 1'b0;
            ensure_queue_empty("TC14");
            finish_test("TC14 Repeated Same Payload Values", e0, a0);
        end
    endtask

    task automatic tc15_corner_data_patterns();
        int e0, a0;
        begin
            start_test("TC15 Corner Data Patterns");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            push_one(8'h00);
            push_one(8'hFF);
            push_one(8'hAA);
            push_one(8'h55);
            tick(4);
            out_ready = 1'b0;
            ensure_queue_empty("TC15");
            finish_test("TC15 Corner Data Patterns", e0, a0);
        end
    endtask

    task automatic tc16_random_valid_ready_throttling();
        int e0, a0;
        int i;
        begin
            start_test("TC16 Random Valid/Ready Throttling");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            for (i = 0; i < RANDOM_CYC; i++) begin
                @(negedge clk);
                in_valid  = $urandom_range(0, 1);
                in_data   = $urandom_range(0, (1<<DATA_W)-1);
                out_ready = $urandom_range(0, 1);
                @(posedge clk);
            end
            @(negedge clk);
            in_valid = 1'b0;
            out_ready = 1'b1;
            drain_all();
            finish_test("TC16 Random Valid/Ready Throttling", e0, a0);
        end
    endtask

    task automatic tc17_long_stall_with_persistent_upstream_requests();
        int e0, a0;
        int i;
        begin
            start_test("TC17 Long Stall With Persistent Upstream Requests");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            for (i = 0; i < (TB_SKID_EN ? 2 : 1); i++) begin
                push_one(8'hC0 + i);
            end
            @(negedge clk);
            in_valid = 1'b1;
            in_data  = 8'hCF;
            tick(5);
            if (TB_SKID_EN) begin
                if (in_ready !== 1'b0) begin
                    $error("Skid mode should backpressure after both entries are occupied");
                    mismatch_count = mismatch_count + 1;
                end
            end else begin
                if (in_ready !== 1'b0) begin
                    $error("Baseline mode should remain not-ready during long stall");
                    mismatch_count = mismatch_count + 1;
                end
            end
            @(negedge clk);
            in_valid  = 1'b0;
            out_ready = 1'b1;
            drain_all();
            finish_test("TC17 Long Stall With Persistent Upstream Requests", e0, a0);
        end
    endtask

    task automatic tc18_random_burst_length_sweep();
        int e0, a0;
        int burst;
        begin
            start_test("TC18 Random Burst Length Sweep");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b1;
            for (burst = 0; burst < 10; burst++) begin
                push_burst($urandom_range(1, 6), burst * 16);
                tick($urandom_range(0, 2));
            end
            tick(8);
            out_ready = 1'b0;
            ensure_queue_empty("TC18");
            finish_test("TC18 Random Burst Length Sweep", e0, a0);
        end
    endtask

    task automatic tc19_reset_during_held_valid();
        int e0, a0;
        begin
            start_test("TC19 Reset During Held Valid");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            out_ready = 1'b0;
            push_one(8'hD1);
            tick(2);
            rst_n = 1'b0;
            tick(2);
            rst_n = 1'b1;
            tick(2);
            if (out_valid !== 1'b0) begin
                $error("Reset-during-held-valid failed: stage should be empty after reset");
                mismatch_count = mismatch_count + 1;
            end
            ensure_queue_empty("TC19");
            finish_test("TC19 Reset During Held Valid", e0, a0);
        end
    endtask

    task automatic tc20_reset_during_streaming_traffic();
        int e0, a0;
        begin
            start_test("TC20 Reset During Streaming Traffic");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            fork
                begin
                    out_ready = 1'b1;
                    push_burst(5, 8'hE0);
                end
                begin
                    tick(3);
                    rst_n = 1'b0;
                    tick(2);
                    rst_n = 1'b1;
                end
            join
            @(negedge clk);
            in_valid  = 1'b0;
            out_ready = 1'b1;
            tick(6);
            out_ready = 1'b0;
            ensure_queue_empty("TC20");
            finish_test("TC20 Reset During Streaming Traffic", e0, a0);
        end
    endtask

    task automatic tc21_recovery_immediately_after_reset();
        int e0, a0;
        begin
            start_test("TC21 Recovery Immediately After Reset");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            push_one(8'h21);
            drain_all();
            finish_test("TC21 Recovery Immediately After Reset", e0, a0);
        end
    endtask

    task automatic tc22_transfer_count_accounting();
        int e0, a0;
        int acc_before, prod_before;
        begin
            start_test("TC22 Transfer Count Accounting");
            e0 = mismatch_count; a0 = assertion_fail_count;
            acc_before  = accepted_total;
            prod_before = produced_total;
            apply_reset();
            out_ready = 1'b1;
            push_burst(12, 8'h30);
            tick(8);
            out_ready = 1'b0;
            if ((accepted_total - acc_before) != 12) begin
                $error("Accepted count mismatch: expected 12 got %0d", accepted_total - acc_before);
                mismatch_count = mismatch_count + 1;
            end
            if ((produced_total - prod_before) != 12) begin
                $error("Produced count mismatch: expected 12 got %0d", produced_total - prod_before);
                mismatch_count = mismatch_count + 1;
            end
            finish_test("TC22 Transfer Count Accounting", e0, a0);
        end
    endtask

    task automatic tc23_assertion_stress_run();
        int e0, a0;
        int i;
        begin
            start_test("TC23 Assertion Stress Run");
            e0 = mismatch_count; a0 = assertion_fail_count;
            apply_reset();
            for (i = 0; i < 300; i++) begin
                @(negedge clk);
                in_valid  = $urandom_range(0, 1);
                in_data   = i;
                out_ready = $urandom_range(0, 1);
                @(posedge clk);
            end
            @(negedge clk);
            in_valid  = 1'b0;
            out_ready = 1'b1;
            drain_all();
            finish_test("TC23 Assertion Stress Run", e0, a0);
        end
    endtask

    task automatic tc24_28_skid_suite();
        int e0, a0;
        begin
            start_test("TC24-TC28 Skid Suite");
            e0 = mismatch_count; a0 = assertion_fail_count;
            if (!TB_SKID_EN) begin
                $display("Skipping skid suite because TB_SKID_EN=0");
                finish_test("TC24-TC28 Skid Suite", e0, a0);
            end else begin
                apply_reset();
                out_ready = 1'b0;
                push_one(8'hF0);
                push_one(8'hF1);
                if (dut.skid_valid_q !== 1'b1) begin
                    $error("Skid check failed: second entry was not captured in skid storage");
                    mismatch_count = mismatch_count + 1;
                end
                tick(3);
                out_ready = 1'b1;
                drain_all();
                finish_test("TC24-TC28 Skid Suite", e0, a0);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------
    initial begin
        rst_n               = 1'b1;
        in_valid            = 1'b0;
        in_data             = '0;
        out_ready           = 1'b0;
        stall_active_prev   = 1'b0;
        stall_data_prev     = '0;
        accepted_total      = 0;
        produced_total      = 0;
        mismatch_count      = 0;
        assertion_fail_count= 0;
        tests_run           = 0;
        tests_failed        = 0;
        cycles              = 0;

        tc01_reset_default_state();
        tc02_first_accept_into_empty();
        tc03_first_output_transfer();
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
        tc16_random_valid_ready_throttling();
        tc17_long_stall_with_persistent_upstream_requests();
        tc18_random_burst_length_sweep();
        tc19_reset_during_held_valid();
        tc20_reset_during_streaming_traffic();
        tc21_recovery_immediately_after_reset();
        tc22_transfer_count_accounting();
        tc23_assertion_stress_run();
        tc24_28_skid_suite();

        $display("\n============================================================");
        $display("Simulation summary");
        $display("  Tests run          : %0d", tests_run);
        $display("  Tests failed       : %0d", tests_failed);
        $display("  Accepted transfers : %0d", accepted_total);
        $display("  Produced transfers : %0d", produced_total);
        $display("  Scoreboard issues  : %0d", mismatch_count);
        $display("  Protocol issues    : %0d", assertion_fail_count);
        $display("============================================================\n");

        if ((tests_failed == 0) && (mismatch_count == 0) && (assertion_fail_count == 0)) begin
            $display("ALL TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "One or more tests failed");
        end
    end

endmodule
