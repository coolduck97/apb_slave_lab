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
    logic        valid_addr;

    // The APB access phase is when both PSEL and PENABLE are high.
    assign apb_access = PSEL && PENABLE;

    // This slave is simple: it is always ready in the access phase.
    assign PREADY = 1'b1;

    // Check whether the address matches one of the registers.
    always_comb begin
        case (PADDR)
            CTRL_ADDR,
            STATUS_ADDR,
            DATA_ADDR:   valid_addr = 1'b1;
            default:     valid_addr = 1'b0;
        endcase
    end

    // PSLVERR is reported only during an APB access to an invalid address.
    assign PSLVERR = apb_access && !valid_addr;

    // Write registers on the clock edge during an APB write access.
    // Reset is synchronous and active-low, so it is checked inside the clocked block.
    always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            ctrl_reg <= 32'h0000_0000;
            data_reg <= 32'h0000_0000;
        end else if (apb_access && PWRITE) begin
            case (PADDR)
                CTRL_ADDR: ctrl_reg <= PWDATA;
                DATA_ADDR: data_reg <= PWDATA;
                default: begin
                    // STATUS is read-only and invalid addresses do not change registers.
                end
            endcase
        end
    end

    // Return read data during an APB read access.
    // For write cycles or idle/setup cycles, PRDATA is driven to zero.
    always_comb begin
        PRDATA = 32'h0000_0000;

        if (apb_access && !PWRITE) begin
            case (PADDR)
                CTRL_ADDR:   PRDATA = ctrl_reg;
                STATUS_ADDR: PRDATA = STATUS_VALUE;
                DATA_ADDR:   PRDATA = data_reg;
                default:     PRDATA = 32'h0000_0000;
            endcase
        end
    end

endmodule
