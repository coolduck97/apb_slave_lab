module apb_master #(
    parameter int NUM_SLAVES = 1
) (
    input  logic        clk,
    input  logic        reset_n,

    // Simple command interface used by the testbench or another block.
    input  logic        write_en,
    input  logic [7:0]  write_addr,
    input  logic [31:0] write_data,
    input  logic        read_en,
    input  logic [7:0]  read_addr,
    output logic [31:0] read_data,
    output logic        read_data_valid,
    output logic        busy,
    output logic        done,
    output logic        error,

    // APB interface driven toward the slaves.
    // PSEL is one-hot: PSEL[0] selects slave 0, PSEL[1] selects slave 1, etc.
    output logic [NUM_SLAVES-1:0] PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [7:0]  PADDR,
    output logic [31:0] PWDATA,
    input  logic [NUM_SLAVES-1:0][31:0] PRDATA,
    input  logic [NUM_SLAVES-1:0]        PREADY,
    input  logic [NUM_SLAVES-1:0]        PSLVERR
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;

    state_t state;

    // Keep track of the current transfer type while APB is busy.
    logic current_is_read;

    logic [3:0]  selected_slave;
    logic        select_valid;
    logic [31:0] selected_prdata;
    logic        selected_pready;
    logic        selected_pslverr;

    // Convert the upper address nibble into a one-hot slave select.
    function automatic logic [NUM_SLAVES-1:0] decode_psel(input logic [7:0] addr);
        logic [NUM_SLAVES-1:0] decoded;
        begin
            decoded = '0;

            for (int i = 0; i < NUM_SLAVES; i++) begin
                if (addr[7:4] == i[3:0]) begin
                    decoded[i] = 1'b1;
                end
            end

            decode_psel = decoded;
        end
    endfunction

    // The upper nibble of PADDR chooses the slave. Invalid slave indexes
    // complete with an error inside the master because no slave is selected.
    assign selected_slave  = PADDR[7:4];
    assign select_valid    = (selected_slave < NUM_SLAVES);
    assign selected_prdata = select_valid ? PRDATA[selected_slave]  : 32'h0000_0000;
    assign selected_pready = select_valid ? PREADY[selected_slave]  : 1'b1;
    assign selected_pslverr = select_valid ? PSLVERR[selected_slave] : 1'b1;

    initial begin
        if (NUM_SLAVES > 16) begin
            $error("NUM_SLAVES must be <= 16 because PADDR[7:4] selects the slave.");
            $finish;
        end
    end

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state           <= IDLE;
            current_is_read <= 1'b0;

            PSEL            <= '0;
            PENABLE         <= 1'b0;
            PWRITE          <= 1'b0;
            PADDR           <= 8'h00;
            PWDATA          <= 32'h0000_0000;

            read_data       <= 32'h0000_0000;
            read_data_valid <= 1'b0;
            busy            <= 1'b0;
            done            <= 1'b0;
            error           <= 1'b0;
        end else begin
            // These are one-cycle pulses. They are set again when needed.
            read_data_valid <= 1'b0;
            done            <= 1'b0;

            case (state)
                IDLE: begin
                    PSEL    <= '0;
                    PENABLE <= 1'b0;
                    busy    <= 1'b0;

                    // If both are requested together, write has priority.
                    if (write_en) begin
                        PSEL            <= decode_psel(write_addr);
                        PENABLE         <= 1'b0;
                        PWRITE          <= 1'b1;
                        PADDR           <= write_addr;
                        PWDATA          <= write_data;
                        current_is_read <= 1'b0;
                        busy            <= 1'b1;
                        error           <= 1'b0;
                        state           <= SETUP;
                    end else if (read_en) begin
                        PSEL            <= decode_psel(read_addr);
                        PENABLE         <= 1'b0;
                        PWRITE          <= 1'b0;
                        PADDR           <= read_addr;
                        PWDATA          <= 32'h0000_0000;
                        current_is_read <= 1'b1;
                        busy            <= 1'b1;
                        error           <= 1'b0;
                        state           <= SETUP;
                    end
                end

                SETUP: begin
                    // APB setup phase lasts one clock. Access starts next.
                    PENABLE <= 1'b1;
                    busy    <= 1'b1;
                    state   <= ACCESS;
                end

                ACCESS: begin
                    PENABLE <= 1'b1;
                    busy    <= 1'b1;

                    // Stay in ACCESS until the slave completes the transfer.
                    if (selected_pready) begin
                        PSEL    <= '0;
                        PENABLE <= 1'b0;
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        error   <= selected_pslverr;

                        if (current_is_read) begin
                            read_data       <= selected_prdata;
                            read_data_valid <= 1'b1;
                        end

                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
