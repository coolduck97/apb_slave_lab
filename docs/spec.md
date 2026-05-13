# APB Slave Specification

## Goal

Create a beginner-friendly APB master connected to an APB slave RTL module.

## APB Version

Use basic AMBA APB-style handshake.

## Interface

### APB Master Command Interface

Inputs:
- clk
- reset_n
- write_en
- write_addr[7:0]
- write_data[31:0]
- read_en
- read_addr[7:0]

Outputs:
- read_data[31:0]
- read_data_valid
- busy
- done
- error

### APB Slave Interface

Inputs:
- PCLK
- PRESETn
- PSEL
- PENABLE
- PWRITE
- PADDR[7:0]
- PWDATA[31:0]

Outputs:
- PRDATA[31:0]
- PREADY
- PSLVERR

## Register Map

| Address | Register | Access |
|---|---|---|
| 0x00 | CTRL   | RW |
| 0x04 | STATUS | RO |
| 0x08 | DATA   | RW |

## Requirements

- Use SystemVerilog
- Synchronous active-low reset
- PREADY goes high when the slave completes the transfer
- PSLVERR is 1 for invalid address
- Write happens during APB access phase:
  - PSEL == 1
  - PENABLE == 1
  - PWRITE == 1
- Read data is returned during APB read access phase:
  - PSEL == 1
  - PENABLE == 1
  - PWRITE == 0
- STATUS register can be fixed value 0x000000A5
- Add comments for learning
