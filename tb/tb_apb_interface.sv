`timescale 1ns/1ps

module tb_apb_interface;

    localparam int NUM_SLAVES = 4;

    logic        PCLK;
    logic        PRESETn;

    // Simple master command interface.
    logic        write_en;
    logic [7:0]  write_addr;
    logic [31:0] write_data;
    logic        read_en;
    logic [7:0]  read_addr;
    logic [31:0] master_read_data;
    logic        master_read_data_valid;
    logic        master_busy;
    logic        master_done;
    logic        master_error;

    // Shared APB command wires from the master.
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;

    // Decoded APB wires for each slave.
    logic [NUM_SLAVES-1:0]        PSEL_s;
    logic [NUM_SLAVES-1:0][31:0]  PRDATA_s;
    logic [NUM_SLAVES-1:0]        PREADY_s;
    logic [NUM_SLAVES-1:0]        PSLVERR_s;

    // Muxed APB response wires back to the master.
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    logic [3:0]  selected_slave;

    // Guard against unsupported settings when upper nibble is slave select.
    initial begin
        if (NUM_SLAVES > 16) begin
            $error("NUM_SLAVES must be <= 16 when PADDR[7:4] selects slave index.");
            $finish;
        end
    end
    logic        select_valid;

    apb_master master (
        .clk             (PCLK),
        .reset_n         (PRESETn),
        .write_en        (write_en),
        .write_addr      (write_addr),
        .write_data      (write_data),
        .read_en         (read_en),
        .read_addr       (read_addr),
        .read_data       (master_read_data),
        .read_data_valid (master_read_data_valid),
        .busy            (master_busy),
        .done            (master_done),
        .error           (master_error),
        .PSEL            (PSEL),
        .PENABLE         (PENABLE),
        .PWRITE          (PWRITE),
        .PADDR           (PADDR),
        .PWDATA          (PWDATA),
        .PRDATA          (PRDATA),
        .PREADY          (PREADY),
        .PSLVERR         (PSLVERR)
    );

    // Use the upper nibble of PADDR to choose a slave.
    assign selected_slave = PADDR[7:4];
    assign select_valid   = (selected_slave < NUM_SLAVES);

    genvar i;
    generate
        for (i = 0; i < NUM_SLAVES; i++) begin : g_slaves
            assign PSEL_s[i] = PSEL && select_valid && (selected_slave == i[3:0]);

            apb_slave slave (
                .PCLK    (PCLK),
                .PRESETn (PRESETn),
                .PSEL    (PSEL_s[i]),
                .PENABLE (PENABLE),
                .PWRITE  (PWRITE),
                // Lower nibble is used as the local register offset per slave.
                .PADDR   ({4'h0, PADDR[3:0]}),
                .PWDATA  (PWDATA),
                .PRDATA  (PRDATA_s[i]),
                .PREADY  (PREADY_s[i]),
                .PSLVERR (PSLVERR_s[i])
            );
        end
    endgenerate

    // Return selected slave response to the master.
    always_comb begin
        PRDATA  = 32'h0000_0000;
        PREADY  = 1'b0;
        PSLVERR = 1'b0;

        if (PSEL && PENABLE) begin
            if (select_valid) begin
                PRDATA  = PRDATA_s[selected_slave];
                PREADY  = PREADY_s[selected_slave];
                PSLVERR = PSLVERR_s[selected_slave];
            end else begin
                // Invalid slave index: complete transfer with an error.
                PREADY  = 1'b1;
                PSLVERR = 1'b1;
            end
        end
    end

    // 100 MHz clock: 10 ns period.
    initial begin
        PCLK = 1'b0;
        forever #5 PCLK = ~PCLK;
    end

    `include "tb/apb_interface_tasks.svh"

    initial begin
        string       wave_file;

        // Wave dumping is controlled by run.py with the +WAVE plusarg.
        if ($test$plusargs("WAVE")) begin
            if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
                wave_file = "wave.vcd";
            end
            $dumpfile(wave_file);
            $dumpvars(0, tb_apb_interface);
        end

        init_test_signals();

        // Synchronous active-low reset: hold reset low across clock edges.
        PRESETn = 1'b0;
        repeat (3) @(posedge PCLK);
        PRESETn <= 1'b1;
        @(posedge PCLK);
        #1;

        run_test();
        finish_test();
    end

endmodule
