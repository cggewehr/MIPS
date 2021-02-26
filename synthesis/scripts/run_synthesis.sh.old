#!/bin/bash

#  Required arguments are:
# PROJECT_DIR (Dir where project files are stored, created by create_project.sh),
# TOP_LVL_ENTITY (Top level entity of project),
# CLOCK_PERIOD (Clock period, in nanoseconds, for synthesis),
# CORNER (Synthesis supply voltage and temperature corner, "wc" for 1.62V @ 125C, "nc" for 1.8V @ 25C, "bc" for 1.98V @ -40C)
# OPTIMIZE_FLAG (Optimize syntesized design) [1 for yes]
# VCD_SIM_FLAG (automattically simulate synhtesized design, generate vcd and generate new power report considering generated VCD) [1 for yes]

# This script must be run after create_project.sh

if [ ! $# -eq "6" ]; 
then 
	echo "Usage: sh run_synthesis.sh <PROJECT_DIR> <TOP_LVL_ENTITY> <CLOCK_PERIOD (in nanoseconds, number only)> <CORNER> <OPTIMIZE_FLAG> <VCD_SIM_FLAG>"
	exit 1
fi

# Export environment variables, to be read in RTLCompiler.tcl
export PROJECT_DIR=$1
export TOP_LVL_ENTITY=$2
export CLOCK_PERIOD=$3
export CORNER=$4
export OPTIMIZE_FLAG=$5
export VCD_SIM_FLAG=$6

# Prints out given arguments for debug
echo "\tRUNNING RTLCompiler WITH ARGS:"
echo "PROJECT_DIR: ${PROJECT_DIR}"
echo "TOP_LVL_ENTITY: ${TOP_LVL_ENTITY}"
echo "CLOCK_PERIOD: ${CLOCK_PERIOD}"
echo "CORNER: ${CORNER}"
echo "OPTIMIZE_FLAG: ${OPTIMIZE_FLAG}"
echo "VCD_SIM_FLAG: ${VCD_SIM_FLAG}"

module add cdn/rc/rc142
module add cdn/incisiv/incisive152

cd ${PROJECT_DIR}/trunk/backend/synthesis/work
rc -64 -logfile ${PROJECT_DIR}/rc.log -cmdfile ${PROJECT_DIR}/rc.cmd -files ${PROJECT_DIR}/trunk/backend/synthesis/scripts/RTLCompiler.tcl

