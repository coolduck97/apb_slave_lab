`timescale 1ns/1ps

module tb_apb_slave;

    localparam logic [7:0] CTRL_ADDR    = 8'h00;
    localparam logic [7:0] STATUS_ADDR  = 8'h04;
    localparam logic [7:0] DATA_ADDR    = 8'h08;
    localparam logic [7:0] INVALID_ADDR = 8'h0C;

    localparam logic [31:0] STATUS_VALUE = 32'h0000_00A5;

    logic        PCLK;
    logic        PRESETn;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    int error_count;

    apb_slave dut (
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

    // Simple checker. Each mismatch increments error_count.
    task automatic check_equal(
        input string name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        begin
            if (actual !== expected) begin
                $display("ERROR: %s expected 0x%08h, got 0x%08h",
                         name, expected, actual);
                error_count++;
            end
        end
    endtask

    // APB write transfer:
    // 1. setup phase: PSEL=1, PENABLE=0
    // 2. access phase: PSEL=1, PENABLE=1
    // 3. wait until PREADY=1, then the transfer is complete
    task automatic apb_write(
        input logic [7:0]  addr,
        input logic [31:0] data
    );
        begin
            @(posedge PCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b1;
            PADDR   <= addr;
            PWDATA  <= data;

            @(posedge PCLK);
            PENABLE <= 1'b1;

            do begin
                @(posedge PCLK);
                #1;
            end while (!PREADY);

            @(posedge PCLK);
            #1;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= 8'h00;
            PWDATA  <= 32'h0000_0000;
        end
    endtask

    // APB read transfer. Data and PSLVERR are sampled when PREADY is high.
    task automatic apb_read(
        input  logic [7:0]  addr,
        output logic [31:0] data,
        output logic        error
    );
        begin
            @(posedge PCLK);
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PADDR   <= addr;
            PWDATA  <= 32'h0000_0000;

            @(posedge PCLK);
            PENABLE <= 1'b1;

            do begin
                @(posedge PCLK);
                #1;
            end while (!PREADY);

            data  = PRDATA;
            error = PSLVERR;

            @(posedge PCLK);
            #1;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PADDR   <= 8'h00;
        end
    endtask

    initial begin
        logic [31:0] read_data;
        logic        read_error;
        string       wave_file;

        // Wave dumping is controlled by run.py with the +WAVE plusarg.
        if ($test$plusargs("WAVE")) begin
            if (!$value$plusargs("WAVE_FILE=%s", wave_file)) begin
                wave_file = "wave.vcd";
            end
            $dumpfile(wave_file);
            $dumpvars(0, tb_apb_slave);
        end

        error_count = 0;

        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PADDR   = 8'h00;
        PWDATA  = 32'h0000_0000;
        PRESETn = 1'b0;

        // Synchronous active-low reset: hold reset low across clock edges.
        repeat (3) @(posedge PCLK);
        PRESETn <= 1'b1;
        @(posedge PCLK);

        // Reset should clear the RW registers.
        apb_read(CTRL_ADDR, read_data, read_error);
        check_equal("CTRL reset value", read_data, 32'h0000_0000);
        check_equal("CTRL reset PSLVERR", {31'b0, read_error}, 32'h0000_0000);

        apb_read(DATA_ADDR, read_data, read_error);
        check_equal("DATA reset value", read_data, 32'h0000_0000);
        check_equal("DATA reset PSLVERR", {31'b0, read_error}, 32'h0000_0000);

        // CTRL register write/read test.
        apb_write(CTRL_ADDR, 32'h1234_5678);
        apb_read(CTRL_ADDR, read_data, read_error);
        check_equal("CTRL readback", read_data, 32'h1234_5678);
        check_equal("CTRL readback PSLVERR", {31'b0, read_error}, 32'h0000_0000);

        // DATA register write/read test.
        apb_write(DATA_ADDR, 32'hCAFE_BABE);
        apb_read(DATA_ADDR, read_data, read_error);
        check_equal("DATA readback", read_data, 32'hCAFE_BABE);
        check_equal("DATA readback PSLVERR", {31'b0, read_error}, 32'h0000_0000);

        // STATUS is read-only and always returns the fixed value.
        apb_write(STATUS_ADDR, 32'hFFFF_FFFF);
        apb_read(STATUS_ADDR, read_data, read_error);
        check_equal("STATUS fixed value", read_data, STATUS_VALUE);
        check_equal("STATUS read PSLVERR", {31'b0, read_error}, 32'h0000_0000);

        // Invalid address should assert PSLVERR during the access phase.
        apb_read(INVALID_ADDR, read_data, read_error);
        check_equal("Invalid address PSLVERR", {31'b0, read_error}, 32'h0000_0001);

        if (error_count == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL");
        end

        $finish;
    end

endmodule
