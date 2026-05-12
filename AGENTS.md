# Project Rules

This project is an RTL training project for a simple APB slave.

## Coding Style

- Use SystemVerilog.
- Keep RTL beginner-friendly.
- Use synthesizable RTL only.
- Avoid vendor-specific primitives.
- Add comments for learning.
- Keep module and signal names easy to understand.

## Verification

- Provide a simple self-checking testbench.
- Test reset behavior.
- Test write/read for CTRL register.
- Test write/read for DATA register.
- Test read-only STATUS register.
- Test invalid address and PSLVERR.

## Simulation

- Use Icarus Verilog.
- Generate wave.vcd.
- Print PASS or FAIL.