localparam logic [7:0] CTRL_ADDR    = 8'h00;
localparam logic [7:0] STATUS_ADDR  = 8'h04;
localparam logic [7:0] DATA_ADDR    = 8'h08;
localparam logic [7:0] INVALID_ADDR = 8'h0C;

localparam logic [31:0] STATUS_VALUE = 32'h0000_00A5;

int error_count;

// Build full APB address from slave index and local register offset.
function automatic logic [7:0] build_addr(
    input int          slave_idx,
    input logic [7:0]  local_addr
);
    logic [7:0] slave_base;
    begin
        // Each slave owns a 16-byte local range. Upper nibble selects slave.
        slave_base = logic'(slave_idx[3:0]) << 4;
        build_addr = slave_base + local_addr;
    end
endfunction

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
    logic [31:0] ctrl_pattern;
    logic [31:0] data_pattern;

    begin
        // The master should leave APB idle after reset.
        check_equal("Master idle after reset", {31'b0, master_busy}, 32'h0000_0000);
        check_equal("APB idle after reset", {30'b0, PSEL, PENABLE}, 32'h0000_0000);

        // Test the same register behavior on every slave instance.
        for (int s = 0; s < NUM_SLAVES; s++) begin
            ctrl_pattern = 32'h1111_0000 + s;
            data_pattern = 32'hCAFE_B000 + s;

            // Reset should clear the slave RW registers.
            master_read(build_addr(s, CTRL_ADDR), read_data, command_error);
            check_equal($sformatf("S%0d CTRL reset value", s), read_data, 32'h0000_0000);
            check_equal($sformatf("S%0d CTRL reset PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);

            master_read(build_addr(s, DATA_ADDR), read_data, command_error);
            check_equal($sformatf("S%0d DATA reset value", s), read_data, 32'h0000_0000);
            check_equal($sformatf("S%0d DATA reset PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);

            // CTRL register write/read.
            master_write(build_addr(s, CTRL_ADDR), ctrl_pattern, command_error);
            check_equal($sformatf("S%0d CTRL write PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);
            master_read(build_addr(s, CTRL_ADDR), read_data, command_error);
            check_equal($sformatf("S%0d CTRL readback", s), read_data, ctrl_pattern);
            check_equal($sformatf("S%0d CTRL readback PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);

            // DATA register write/read.
            master_write(build_addr(s, DATA_ADDR), data_pattern, command_error);
            check_equal($sformatf("S%0d DATA write PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);
            master_read(build_addr(s, DATA_ADDR), read_data, command_error);
            check_equal($sformatf("S%0d DATA readback", s), read_data, data_pattern);
            check_equal($sformatf("S%0d DATA readback PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);

            // STATUS is read-only and always returns fixed value.
            master_write(build_addr(s, STATUS_ADDR), 32'hFFFF_FFFF, command_error);
            check_equal($sformatf("S%0d STATUS write PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);
            master_read(build_addr(s, STATUS_ADDR), read_data, command_error);
            check_equal($sformatf("S%0d STATUS fixed value", s), read_data, STATUS_VALUE);
            check_equal($sformatf("S%0d STATUS read PSLVERR", s), {31'b0, command_error}, 32'h0000_0000);

            // Invalid local register offset inside a valid slave range.
            master_read(build_addr(s, INVALID_ADDR), read_data, command_error);
            check_equal($sformatf("S%0d invalid local addr PSLVERR", s), {31'b0, command_error}, 32'h0000_0001);
        end

        // Invalid slave index should assert PSLVERR from the interconnect.
        master_read(build_addr(NUM_SLAVES, CTRL_ADDR), read_data, command_error);
        check_equal("Invalid slave index PSLVERR", {31'b0, command_error}, 32'h0000_0001);
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
