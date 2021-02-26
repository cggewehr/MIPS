
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_textio.all;

library std;
	use std.textio.all;


package MIPS_PKG is

	-- Pipeline stages input interfaces
	type FetchInput is record

		-- Computed next PC value from a branch instruction, determined in the Execute stage
		BranchTakeFlag: std_logic;
		BranchAddress: std_logic_vector(31 downto 0);

		-- Instruction read from instruction memory, addressed by PC
		InstructionMemoryDataOut: std_logic_vector(31 downto 0);

	end record;

	type DecodeInput is record

		-- PC + 4, used in computing the jump address in the Execute stage
		IncrementedPC: std_logic_vector(31 downto 0);

		-- Next instruction, read from instruction memory in the Fetch stage
		Instruction: std_logic_vector(31 downto 0);
		
		-- Feedback from Execute stage regarding branch status
		BranchOverride: std_logic;
		BranchStateEnable: std_logic;

		-- Writeback info, from Writeback stage
		WritebackEnable: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);
		WritebackData: std_logic_vector(31 downto 0);

	end record;

	type ExecuteInput is record

		-- Data to manipulate, determined in Decode stage
		Data1: std_logic_vector(31 downto 0);
		Data2: std_logic_vector(31 downto 0);
		IMM: std_logic_vector(15 downto 0);
		RS: std_logic_vector(4 downto 0);
		RT: std_logic_vector(4 downto 0);

		-- Data from Writeback stage, used in forwarding unit
		WBStageData: std_logic_vector(31 downto 0);
		WBStageReg: std_logic_vector(4 downto 0);
		WBStageEnable: std_logic;

		-- PC + 4, used in computing the jump address in a branch instruction
		--IncrementedPC: std_logic_vector(31 downto 0);
		BranchWasTaken: std_logic;

		-- Execute stage control signals
		ALUOP: std_logic_vector(2 downto 0);
		ArithmeticExtendFlag: std_logic;
        ArithmeticImmediateFlag: std_logic;
        ArithmeticUnsignedFlag: std_logic;

		BranchInstructionFlag: std_logic;
		BranchInstructionAroundZero: std_logic;
		ComparatorMasks: std_logic_vector(2 downto 0);
		JumpFromImmediate: std_logic;

		SetFlag: std_logic;
		SetImmediate: std_logic;
		SetUnsigned: std_logic;

		ShifterFlag: std_logic;
		ShifterArithmetic: std_logic;
		ShifterLeft: std_logic;
		ShifterVariable: std_logic;

		-- Memory Access stage control signals
		MemoryAccessFlag: std_logic;
		MemoryAccessLoad: std_logic;
		MemoryAccessUnsigned: std_logic;
		MemoryAccessGranularity: std_logic_vector(1 downto 0);

		-- Writeback stage control signals
		LUIFlag: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);
		WritebackEnable: std_logic;

	end record;

	type MemoryAccessInput is record

		-- Used either as a memory address in which data will be written to/read from, determined in the Execute stage; or passed-through to Writeback stage
		ALUData: std_logic_vector(31 downto 0);

		-- Data to be written on memory at the specified address
		RegBankPassThrough: std_logic_vector(31 downto 0);

		RT: std_logic_vector(4 downto 0);
		
		--LuiFlag: std_logic;
		
	    DataMemDataOut: std_logic_vector(31 downto 0);

		-- Memory Access stage control signals
		MemoryAccessFlag: std_logic;
		MemoryAccessLoad: std_logic;
		MemoryAccessUnsigned: std_logic;
		MemoryAccessGranularity: std_logic_vector(1 downto 0);
		
		WritebackEnable: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);

	end record;

	type WritebackInput is record

		-- Either data read from memory or determined by the ALU
		WritebackEnable: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);
		WritebackData: std_logic_vector(31 downto 0);

	end record;


	-- Pipeline stages output registers
	type FetchOutput is record

		-- PC + 4, used in computing the jump address in the Execute stage
		IncrementedPC: std_logic_vector(31 downto 0);

		-- Address to instruction memory (PC)
		InstructionMemoryAddress: std_logic_vector(31 downto 0);

		-- Fetched instruction from instruction memory, to be decoded in the Decode stage
		Instruction: std_logic_vector(31 downto 0);

	end record;

	type DecodeOutput is record

		-- Passes-through PC + 4, used in computing the jump address in the Execute stage
		--IncrementedPC: std_logic_vector(31 downto 0);
		BranchWasTaken: std_logic;
		BranchTakeFlag: std_logic;
		BranchAddress: std_logic_vector(31 downto 0);

		-- Data values read from register bank
		Data1: std_logic_vector(31 downto 0);
		Data2: std_logic_vector(31 downto 0);
		IMM: std_logic_vector(15 downto 0);
		RS: std_logic_vector(4 downto 0);
		RT: std_logic_vector(4 downto 0);

		-- Execute control signals
		ALUOP: std_logic_vector(2 downto 0);
		ArithmeticExtendFlag: std_logic;
        ArithmeticImmediateFlag: std_logic;
        ArithmeticUnsignedFlag: std_logic;

		BranchInstructionFlag: std_logic;
		BranchInstructionAroundZero: std_logic;
		ComparatorMasks: std_logic_vector(2 downto 0);
		JumpFromImmediate: std_logic;
		
		LUIFlag: std_logic;

		SetFlag: std_logic;
		SetImmediate: std_logic;
		SetUnsigned: std_logic;

		ShifterFlag: std_logic;
		ShifterArithmetic: std_logic;
		ShifterLeft: std_logic;
		ShifterVariable: std_logic;

		-- Memory Access stage control signals
		MemoryAccessFlag: std_logic;
		MemoryAccessLoad: std_logic;
		MemoryAccessUnsigned: std_logic;
		MemoryAccessGranularity: std_logic_vector(1 downto 0);

		-- Writeback stage control signals
		WritebackReg: std_logic_vector(4 downto 0);
		WritebackEnable: std_logic;

	end record;

	type ExecuteOutput is record

		-- Memory Access stage data
		ALUResult: std_logic_vector(31 downto 0);
		RegBankPassthrough: std_logic_vector(31 downto 0);
		RT: std_logic_vector(4 downto 0);
		
		-- Computed branch information
		--BranchTakeFlag: std_logic;
		--BranchAddress: std_logic_vector(31 downto 0);
		BranchOverride: std_logic;
		BranchStateEnable: std_logic;

		-- Memory Access stage control signals
		--LUIFlag: std_logic;
		MemoryAccessFlag: std_logic;
		MemoryAccessLoad: std_logic;
		MemoryAccessUnsigned: std_logic;
		MemoryAccessGranularity: std_logic_vector(1 downto 0);

		-- Writeback stage control signals
		WritebackEnable: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);
		
	end record;

	type MemoryAccessOutput is record
	
	    DataMemWrite: std_logic;
	    DataMemAddress: std_logic_vector(31 downto 0);
	    DataMemDataIn: std_logic_vector(31 downto 0);

		-- Data read from memory from the specified address
		WritebackEnable: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);
		WritebackData: std_logic_vector(31 downto 0); 

	end record;

	type WritebackOutput is record

		WritebackEnable: std_logic;
		WritebackReg: std_logic_vector(4 downto 0);
		WritebackData: std_logic_vector(31 downto 0); 

	end record;

	--type StringArray is array(natural range <>) of string;
	--constant InstructionManifest: StringArray(0 to 11) := (

	--	-- R type 
	--	"ADDU", 
	--	"SUBU", 
	--	"AND", 
	--	"OR",

	--	-- I type 
	--	"LW", 
	--	"SW",  
	--	"ADDIU", 
	--	"ORI", 
	--	"SLT", 
	--	"BEQ", 
	--	"LUI",

	--	-- J type
	--	"J"
	--);

	---- DEBUG FUNCIONS

	---- Decodes the OPCODE field of a fetched instruction
	--function DecodeOPCODE(OPCODE: std_logic_vector(5 downto 0)) return string;

	---- Checks if a decoded instruction is implemented
	--function CheckInstruction(DecodedInstruction: string; InstructionManifest: StringArray) return boolean;
	
end package MIPS_PKG;


package body MIPS_PKG is

	--TODO:
	---- Decodes the OPCODE field of a fetched instruction. OPCODE values taken from "opencores.org/projects/plasma/opcodes"
	--function DecodeOPCODE(OPCODE: std_logic_vector(5 downto 0)) return string is

	--begin

	--	case (OPCODE) is

	--		-- R type instructions
	--		when "000000" =>
	--			return "R";

	--		-- I type arithmetic instructions
	--		when "001000" => 
	--			return "ADDI";

	--		when "001001" => 
	--			return "ADDIU";

	--		when "001100" => 
	--			return "ANDI";

	--		when "001111" => 
	--			return "LUI";

	--		when "001101" => 
	--			return "ORI";

	--		when "001010" => 
	--			return "SLTI";

	--		when "001011" => 
	--			return "SLTIU";

	--		when "001110" => 
	--			return "XORI";

	--		-- Branch instructions
	--		when "000100" =>
	--			return "BEQ";

	--		when "000111" => .
	--			return "BGTZ";

	--		when "000001" =>  -- THIS IS NOT UP TO MIPS STANDARD, AS THE "000001" OPCODE IS SHARED BY SOME OTHER BRANCH INSTRUCTIONS, WHICH ARE NOT IMPLEMENTED () 
	--			return "BLTZ";
				
	--		when others =>
	--			report "OPCODE " & OPCODE'image & " not recognized" severity failure;

	--	end case;

	--end function DecodeOPCODE;

end package body MIPS_PKG;
