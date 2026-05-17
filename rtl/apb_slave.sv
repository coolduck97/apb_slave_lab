module apb_slave (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [7:0]  PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR
);

    // Register addresses. Only the low byte of PADDR is used in this lab.
    localparam logic [7:0] CTRL_ADDR   = 8'h00;
    localparam logic [7:0] STATUS_ADDR = 8'h04;
    localparam logic [7:0] DATA_ADDR   = 8'h08;

    // STATUS is read-only and returns the same value every time.
    localparam logic [31:0] STATUS_VALUE = 32'h0000_00A5;

    logic [31:0] ctrl_reg;
    logic [31:0] data_reg;

    logic        apb_access;
    logic        wait_done;
    logic        transfer_done;
    logic        valid_addr;
    logic [7:0]  local_addr;

    // The APB access phase is when both PSEL and PENABLE are high.
    assign apb_access = PSEL && PENABLE;

    // In a multi-slave system, PADDR[7:4] selects the slave.
    // Each slave uses PADDR[3:0] as its local register offset.
    assign local_addr = {4'h0, PADDR[3:0]};

    // PREADY is low for the first access cycle, then high on the next cycle.
    // This shows how an APB slave can add a simple wait state.
    assign PREADY = apb_access && wait_done;

    // A transfer finishes only when the slave says it is ready.
    assign transfer_done = apb_access && PREADY;

    // Check whether the address matches one of the registers.
    always_comb begin
        case (local_addr)
            CTRL_ADDR,
            STATUS_ADDR,
            DATA_ADDR:   valid_addr = 1'b1;
            default:     valid_addr = 1'b0;
        endcase
    end

    // wait_done remembers that the first access cycle has already passed.
    always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            wait_done <= 1'b0;
        end else if (apb_access && !wait_done) begin
            wait_done <= 1'b1;
        end else begin
            wait_done <= 1'b0;
        end
    end

    // PSLVERR is reported when an APB transfer completes with an invalid address.
    assign PSLVERR = transfer_done && !valid_addr;

    // Write registers on the clock edge during an APB write access.
    // Reset is synchronous and active-low, so it is checked inside the clocked block.
    always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            ctrl_reg <= 32'h0000_0000;
            data_reg <= 32'h0000_0000;
        end else if (transfer_done && PWRITE) begin
            case (local_addr)
                CTRL_ADDR: ctrl_reg <= PWDATA;
                DATA_ADDR: data_reg <= PWDATA;
                default: begin
                    // STATUS is read-only and invalid addresses do not change registers.
                end
            endcase
        end
    end

    // Return read data when an APB read transfer completes.
    // For write cycles or idle/setup cycles, PRDATA is driven to zero.
    always_comb begin
        PRDATA = 32'h0000_0000;

        if (transfer_done && !PWRITE) begin
            case (local_addr)
                CTRL_ADDR:   PRDATA = ctrl_reg;
                STATUS_ADDR: PRDATA = STATUS_VALUE;
                DATA_ADDR:   PRDATA = data_reg;
                default:     PRDATA = 32'h0000_0000;
            endcase
        end
    end

endmodule
