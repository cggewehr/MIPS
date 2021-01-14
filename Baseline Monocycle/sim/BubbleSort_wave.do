onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /mips_monocycle_tb/mips_monocycle/reset
add wave -noupdate -format Logic /mips_monocycle_tb/mips_monocycle/clock
add wave -noupdate -format Literal -radix hexadecimal /mips_monocycle_tb/mips_monocycle/instructionaddress
add wave -noupdate -format Literal -radix hexadecimal /mips_monocycle_tb/mips_monocycle/dataaddress
add wave -noupdate -format Literal /mips_monocycle_tb/mips_monocycle/control_path/decodedinstruction
add wave -noupdate -format Literal -radix hexadecimal -expand /mips_monocycle_tb/mips_monocycle/data_path/register_file/reg
add wave -noupdate -divider {Data Memory}
add wave -noupdate -format Literal -radix hexadecimal /mips_monocycle_tb/data_memory/memoryarray
add wave -noupdate -divider {Instruction Memory}
add wave -noupdate -format Literal -radix hexadecimal /mips_monocycle_tb/instruction_memory/memoryarray
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {21 ns} 0}
configure wave -namecolwidth 150
configure wave -valuecolwidth 66
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {68 ns}
