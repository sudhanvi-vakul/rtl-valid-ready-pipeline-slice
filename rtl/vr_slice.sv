`timescale 1ns/1ps

module vr_slice #(
    parameter integer DATA_W  = 16,
    parameter integer SKID_EN = 0,
    parameter integer DBG_EN  = 1
) (
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 in_valid,
    output wire                 in_ready,
    input  wire [DATA_W-1:0]    in_data,

    output wire                 out_valid,
    input  wire                 out_ready,
    output wire [DATA_W-1:0]    out_data,

    output wire                 dbg_accept,
    output wire                 dbg_produce,
    output wire                 dbg_hold,
    output wire                 dbg_skid_active,
    output wire [1:0]           dbg_occupancy
);

    reg                  main_valid_q;
    reg [DATA_W-1:0]     main_data_q;
    reg                  skid_valid_q;
    reg [DATA_W-1:0]     skid_data_q;

    wire take_out;
    wire take_in;

    assign out_valid = main_valid_q;
    assign out_data  = main_data_q;

    assign take_out = main_valid_q && out_ready;

    generate
        if (SKID_EN != 0) begin : g_skid_ready
            assign in_ready = (!skid_valid_q) || take_out;
        end else begin : g_noskid_ready
            assign in_ready = (!main_valid_q) || take_out;
        end
    endgenerate

    assign take_in = in_valid && in_ready;

    wire [1:0] occupancy_int;
    assign occupancy_int = {1'b0, main_valid_q} + {1'b0, skid_valid_q};

    generate
        if (DBG_EN != 0) begin : g_dbg_on
            assign dbg_accept      = take_in;
            assign dbg_produce     = take_out;
            assign dbg_hold        = main_valid_q && !out_ready;
            assign dbg_skid_active = skid_valid_q;
            assign dbg_occupancy   = occupancy_int;
        end else begin : g_dbg_off
            assign dbg_accept      = 1'b0;
            assign dbg_produce     = 1'b0;
            assign dbg_hold        = 1'b0;
            assign dbg_skid_active = 1'b0;
            assign dbg_occupancy   = 2'b00;
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_valid_q <= 1'b0;
            main_data_q  <= {DATA_W{1'b0}};
            skid_valid_q <= 1'b0;
            skid_data_q  <= {DATA_W{1'b0}};
        end else begin
            if (SKID_EN != 0) begin
                if (take_out) begin
                    if (skid_valid_q) begin
                        main_valid_q <= 1'b1;
                        main_data_q  <= skid_data_q;
                        if (take_in) begin
                            skid_valid_q <= 1'b1;
                            skid_data_q  <= in_data;
                        end else begin
                            skid_valid_q <= 1'b0;
                            skid_data_q  <= skid_data_q;
                        end
                    end else begin
                        if (take_in) begin
                            main_valid_q <= 1'b1;
                            main_data_q  <= in_data;
                        end else begin
                            main_valid_q <= 1'b0;
                            main_data_q  <= main_data_q;
                        end
                        skid_valid_q <= 1'b0;
                        skid_data_q  <= skid_data_q;
                    end
                end else begin
                    if (take_in) begin
                        if (!main_valid_q) begin
                            main_valid_q <= 1'b1;
                            main_data_q  <= in_data;
                        end else if (!skid_valid_q) begin
                            skid_valid_q <= 1'b1;
                            skid_data_q  <= in_data;
                        end
                    end
                end
            end else begin
                skid_valid_q <= 1'b0;
                skid_data_q  <= {DATA_W{1'b0}};

                if (take_out) begin
                    if (take_in) begin
                        main_valid_q <= 1'b1;
                        main_data_q  <= in_data;
                    end else begin
                        main_valid_q <= 1'b0;
                        main_data_q  <= main_data_q;
                    end
                end else if (take_in) begin
                    main_valid_q <= 1'b1;
                    main_data_q  <= in_data;
                end
            end
        end
    end

endmodule
