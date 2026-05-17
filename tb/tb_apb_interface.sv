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

    // APB command wires from the master.
    logic [NUM_SLAVES-1:0] PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;

    // APB response wires from each slave.
    logic [NUM_SLAVES-1:0][31:0]  PRDATA_s;
    logic [NUM_SLAVES-1:0]        PREADY_s;
    logic [NUM_SLAVES-1:0]        PSLVERR_s;

    apb_master #(
        .NUM_SLAVES     (NUM_SLAVES)
    ) master (
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
        .PRDATA          (PRDATA_s),
        .PREADY          (PREADY_s),
        .PSLVERR         (PSLVERR_s)
    );

    genvar i;
    generate
        for (i = 0; i < NUM_SLAVES; i++) begin : g_slaves
            apb_slave slave (
                .PCLK    (PCLK),
                .PRESETn (PRESETn),
                .PSEL    (PSEL[i]),
                .PENABLE (PENABLE),
                .PWRITE  (PWRITE),
                .PADDR   (PADDR),
                .PWDATA  (PWDATA),
                .PRDATA  (PRDATA_s[i]),
                .PREADY  (PREADY_s[i]),
                .PSLVERR (PSLVERR_s[i])
            );
        end
    endgenerate

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
