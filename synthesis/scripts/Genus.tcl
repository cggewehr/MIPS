
# Define auxiliary vars defined by shell script
#set HDLSourcesFile env(SynthHDLSourcesFile)
#set SDCFile $env(SynthSDCFile)
set ProjectDir $env(SynthProjectDir)
set VoltageLevel $env(SynthVoltageLevel)
set ProcessCorner $env(SynthProcessCorner)
set ClockPeriod $env(SynthClockPeriod)

# Read cell library & LEF
#read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/cds.lib

# PVT = Slow 1.1V 0C
#read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_basicCells.lib
#read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_extvdd1v0.lib
#read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_extvdd1v2.lib
#read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_multibitsDFF.lib

# PVT = Fast 1.32V 0C
# read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/fast_vdd1v2_basicCells.lib
# read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/fast_vdd1v2_extvdd1v0.lib
# read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/fast_vdd1v2_extvdd1v2.lib
# read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/fast_vdd1v2_multibitsDFF.lib

set DesignKitDir "/home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/"
set CellLibDir "${DesignKitDir}/gsclib045/"
set TechDir "${DesignKitDir}/gsclib045_tech/"

# Set cell lib characterizations
if {$ProcessCorner == "Slow" || $ProcessCorner == "s"} {

    if {$VoltageLevel == "1.1" || $VoltageLevel == "1.1V"} {
	    #read_libs /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045/timing/slow_vdd1v0_basicCells.lib
	    read_libs "${CellLibDir}/timing/slow_vdd1v0_basicCells.lib ${CellLibDir}/timing/slow_vdd1v0_multibitsDFF.lib"
	    #read_libs "${CellLibDir}/timing/slow_vdd1v0_multibitsDFF.lib"
    } elseif {$VoltageLevel == "1.32" || $VoltageLevel == "1.32V"} {
	    read_libs "${CellLibDir}/timing/slow_vdd1v2_basicCells.lib ${CellLibDir}/timing/slow_vdd1v2_multibitsDFF.lib"
    } else {
	    puts "VoltageLevel value <${VoltageLevel}> not recognized. Supported values are \"1.1\", \"1.1V\", \"1.32\", \"1.32V\". For further information refer to cell lib README"
        exit
    }

} elseif {$ProcessCorner == "Fast" || $ProcessCorner == "f"} {

    if {$VoltageLevel == "1.1" || $VoltageLevel == "1.1V"} {
	    read_libs "${CellLibDir}/timing/fast_vdd1v0_basicCells.lib ${CellLibDir}/timing/fast_vdd1v0_multibitsDFF.lib"
    } elseif {$VoltageLevel == "1.32" || $VoltageLevel == "1.32V"} {
	    read_libs "${CellLibDir}/timing/fast_vdd1v2_basicCells.lib ${CellLibDir}/timing/fast_vdd1v2_multibitsDFF.lib"
    } else {
	    puts "VoltageLevel value <${VoltageLevel}> not recognized. Supported values are \"1.1\", \"1.1V\", \"1.32\", \"1.32V\". For further information refer to cell lib README"
        exit
    }

} else {
    puts "Process value <${ProcessCorner}> not recognized. Supported values are \"Slow\", \"s\", \"Fast\", \"f\". For further information refer to cell lib README"
    exit
}

# STD cell layout info
#read_physical /home/tools/design_kits/cadence_pdks/gpdk045_45nm_cmos_11m-2p/reference_libs/GPDK045/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef
read_physical -lefs "${CellLibDir}/lef/gsclib045_tech.lef ${CellLibDir}/lef/gsclib045_macro.lef ${CellLibDir}/lef/gsclib045_multibitsDFF.lef"
#read_physical -lefs "${TechDir}/lef/gsclib045_macro.lef"
#read_physical -lefs "${TechDir}/lef/gsclib045_multibitsDFF.lef"

# Parasitic extraction rules
#set_db qrc_tech_file "${TechDir}/qrc/qx/gsclib045.tch"
set_db qrc_tech_file "${CellLibDir}/qrc/qx/gpdk045.tch"

# Read HDL sources
set_db hdl_language vhdl
set_db hdl_vhdl_read_version 1993
set SourcesDir "${ProjectDir}/src"
set_db init_hdl_search_path $SourcesDir
set HDLSourcesFile "${ProjectDir}/synthesis/scripts/fileList.tcl"
source $HDLSourcesFile
#read_hdl -f ${HDLSourcesFile}

# Elaborates top level entity
elaborate "MIPS"

# Prints elaboration report
check_design -all

# Read constraints
set SDCFile "${ProjectDir}/synthesis/scripts/constraints.sdc"
read_sdc $SDCFile
check_timing_intent -verbose

# Synthesize design
set_db "syn_generic_effort" "high"
syn_generic

set_db "syn_map_effort" "high"
syn_map

set_db "syn_opt_effort" "high"
syn_opt

# Generate reports
#write_snapshot -outdir "." -tag "after_opt"
set ReportDir "${ProjectDir}/synthesis/deliverables"
report_area > "${ReportDir}/area.rpt"
report_design_rules > "${ReportDir}/design_rules.rpt"
report_power > "${ReportDir}/power.rpt"
report_timing > "${ReportDir}/timing.rpt"
write_hdl > "${ReportDir}/MIPS.v"
#report_summary
report_messages

# TODO: Call NCSim.tcl to generate VCD file and re-evaluate power
