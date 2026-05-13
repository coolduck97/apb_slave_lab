localparam logic [7:0] CTRL_ADDR    = 8'h00;
localparam logic [7:0] STATUS_ADDR  = 8'h04;
localparam logic [7:0] DATA_ADDR    = 8'h08;
localparam logic [7:0] INVALID_ADDR = 8'h0C;

localparam logic [31:0] STATUS_VALUE = 32'h0000_00A5;

int error_count;

// Set all testbench command signals to known idle values.
task automatic init_test_signals;
    begin
        error_count = 0;

        write_en   = 1'b0;
        write_addr = 8'h00;
        write_data = 32'h0000_0000;
        read_en    = 1'b0;
        read_addr  = 8'h00;
    end
endtask

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

// Run the full APB master/slave self-checking scenario.
task automatic run_test;
    logic [31:0] read_data;
    logic        command_error;

    begin
        // The master should leave APB idle after reset.
        check_equal("Master idle after reset", {31'b0, master_busy}, 32'h0000_0000);
        check_equal("APB idle after reset", {30'b0, PSEL, PENABLE}, 32'h0000_0000);

        // Reset should clear the slave RW registers.
        master_read(CTRL_ADDR, read_data, command_error);
        check_equal("CTRL reset value", read_data, 32'h0000_0000);
        check_equal("CTRL reset PSLVERR", {31'b0, command_error}, 32'h0000_0000);

        master_read(DATA_ADDR, read_data, command_error);
        check_equal("DATA reset value", read_data, 32'h0000_0000);
        check_equal("DATA reset PSLVERR", {31'b0, command_error}, 32'h0000_0000);

        // CTRL register write/read test through the APB master.
        master_write(CTRL_ADDR, 32'h1234_5678, command_error);
        check_equal("CTRL write PSLVERR", {31'b0, command_error}, 32'h0000_0000);
        master_read(CTRL_ADDR, read_data, command_error);
        check_equal("CTRL readback", read_data, 32'h1234_5678);
        check_equal("CTRL readback PSLVERR", {31'b0, command_error}, 32'h0000_0000);

        // DATA register write/read test through the APB master.
        master_write(DATA_ADDR, 32'hCAFE_BABE, command_error);
        check_equal("DATA write PSLVERR", {31'b0, command_error}, 32'h0000_0000);
        master_read(DATA_ADDR, read_data, command_error);
        check_equal("DATA readback", read_data, 32'hCAFE_BABE);
        check_equal("DATA readback PSLVERR", {31'b0, command_error}, 32'h0000_0000);

        // STATUS is read-only and always returns the fixed value.
        master_write(STATUS_ADDR, 32'hFFFF_FFFF, command_error);
        check_equal("STATUS write PSLVERR", {31'b0, command_error}, 32'h0000_0000);
        master_read(STATUS_ADDR, read_data, command_error);
        check_equal("STATUS fixed value", read_data, STATUS_VALUE);
        check_equal("STATUS read PSLVERR", {31'b0, command_error}, 32'h0000_0000);

        // Invalid address should assert PSLVERR during the APB transfer.
        master_read(INVALID_ADDR, read_data, command_error);
        check_equal("Invalid address PSLVERR", {31'b0, command_error}, 32'h0000_0001);
    end
endtask

// Print final result and stop the simulation.
task automatic finish_test;
    begin
        if (error_count == 0) begin
            $display("PASS");
        end else begin
            $display("FAIL");
        end

        $finish;
    end
endtask

// Send one write command into the master. The master creates APB cycles.
task automatic master_write(
    input logic [7:0]  addr,
    input logic [31:0] data,
    output logic       error
);
    begin
        @(posedge PCLK);
        #1;
        write_addr <= addr;
        write_data <= data;
        write_en   <= 1'b1;

        @(posedge PCLK);
        #1;
        write_en <= 1'b0;

        do begin
            @(posedge PCLK);
            #1;
        end while (!master_done);

        error = master_error;
    end
endtask

// Send one read command into the master and collect the returned data.
task automatic master_read(
    input  logic [7:0]  addr,
    output logic [31:0] data,
    output logic        error
);
    begin
        @(posedge PCLK);
        #1;
        read_addr <= addr;
        read_en   <= 1'b1;

        @(posedge PCLK);
        #1;
        read_en <= 1'b0;

        do begin
            @(posedge PCLK);
            #1;
        end while (!master_read_data_valid && !master_done);

        data  = master_read_data;
        error = master_error;
    end
endtask
