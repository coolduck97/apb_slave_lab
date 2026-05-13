#!/usr/bin/env bash
set -e

echo "== APB master/slave simulation =="

echo "[1/2] Compiling RTL and testbench..."
iverilog -g2012 \
    -o simv \
    rtl/apb_master.sv \
    rtl/apb_slave.sv \
    tb/tb_apb_interface.sv

echo "[2/2] Running simulation..."
vvp simv +WAVE +WAVE_FILE=wave.vcd

echo "Simulation complete."
echo "Generated files: simv, wave.vcd"
