# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -path "$::DIR_PATH/rtl/vhdl/AxiSpaceWire.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwpkg.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwstream.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwlink.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwram.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwrecv.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwxmit.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwxmit_fast.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwrecvfront_generic.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/spwrecvfront_fast.vhd"
loadSource -path "$::DIR_PATH/rtl/vhdl/syncdff_v2.vhd"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/bench/vhdl"
