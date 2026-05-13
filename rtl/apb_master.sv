module apb_master (
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

    // APB interface driven toward the slave.
    output logic        PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [7:0]  PADDR,
    output logic [31:0] PWDATA,
    input  logic [31:0] PRDATA,
    input  logic        PREADY,
    input  logic        PSLVERR
);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;

    state_t state;

    // Keep track of the current transfer type while APB is busy.
    logic current_is_read;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state           <= IDLE;
            current_is_read <= 1'b0;

            PSEL            <= 1'b0;
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
                    PSEL    <= 1'b0;
                    PENABLE <= 1'b0;
                    busy    <= 1'b0;

                    // If both are requested together, write has priority.
                    if (write_en) begin
                        PSEL            <= 1'b1;
                        PENABLE         <= 1'b0;
                        PWRITE          <= 1'b1;
                        PADDR           <= write_addr;
                        PWDATA          <= write_data;
                        current_is_read <= 1'b0;
                        busy            <= 1'b1;
                        error           <= 1'b0;
                        state           <= SETUP;
                    end else if (read_en) begin
                        PSEL            <= 1'b1;
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
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b1;
                    busy    <= 1'b1;
                    state   <= ACCESS;
                end

                ACCESS: begin
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b1;
                    busy    <= 1'b1;

                    // Stay in ACCESS until the slave completes the transfer.
                    if (PREADY) begin
                        PSEL    <= 1'b0;
                        PENABLE <= 1'b0;
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        error   <= PSLVERR;

                        if (current_is_read) begin
                            read_data       <= PRDATA;
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
