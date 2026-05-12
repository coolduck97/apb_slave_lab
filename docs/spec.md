# APB Slave Specification

## Goal

Create a beginner-friendly APB slave RTL module.

## APB Version

Use basic AMBA APB-style handshake.

## Interface

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
- PREADY is always 1
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