`timescale 1ns/1ps

module tb_apb_interface;

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

    // APB wires between master and slave.
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

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

    apb_slave slave (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PADDR   (PADDR),
        .PWDATA  (PWDATA),
        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR)
    );

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
