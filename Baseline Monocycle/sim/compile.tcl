# TCL ModelSim compile script
# Pay atention on the compilation order!!!



# Sets the compiler
#set compiler vlog
set compiler vcom


# Creats the work library if it does not exist
if { ![file exist work] } {
    vlib work
}




#########################
### Source files list ###
#########################

# Source files listed in hierarchical order: botton -> top
set sourceFiles {
    ../src/MIPS_package.vhd
    ../src/RegisterNbits.vhd
    ../src/RegisterFile.vhd
    ../src/ALU.vhd
    ../src/DataPath.vhd 
    ../src/ControlPath.vhd
    ../src/MIPS_monocycle.vhd
    Util_package.vhd
    Memory.vhd
    MIPS_monocycle_tb.vhd
}



set top MIPS_monocycle_tb



###################
### Compilation ###
###################

if { [llength $sourceFiles] > 0 } {
    
    foreach file $sourceFiles {
        if [ catch {$compiler $file} ] {
            puts "\n*** ERROR compiling file $file :( ***" 
            return;
        }
    }
}




################################
### Lists the compiled files ###
################################

if { [llength $sourceFiles] > 0 } {
    
    puts "\n*** Compiled files:"  
    
    foreach file $sourceFiles {
        puts \t$file
    }
}


puts "\n*** Compilation OK ;) ***"

#vsim $top
#set StdArithNoWarnings 1

