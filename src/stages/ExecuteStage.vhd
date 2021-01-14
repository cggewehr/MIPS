--------------------------------------------------------------------------------
-- Title       : ExecuteStage
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : ExecuteStage.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Implements Execute stage in the 5 stage pipeline
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Gewehr: Initial implementation
--------------------------------------------------------------------------------
-- TODO        : Implement MUL/DIV
--               Implement forwarding
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


entity ExecuteStage is

	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		InputInterface: in ExecuteInput;  -- Defined in MIPS_PKG
		OutputInterface: out ExecuteOutput  -- Defined in MIPS_PKG

	);
	
end entity ExecuteStage;


architecture RTL of ExecuteStage is

	-- Comparator signals
	ComparatorFlags: std_logic_vector(2 downto 0);

	-- ALU signals
	ALUData: std_logic_vector(31 downto 0);
	ALUFlags: std_logic_vector(3 downto 0);  -- Negative, Zero, Carry, Overflow

	-- Shifter signals
	ShifterData: std_logic_vector(31 downto 0);

begin

	--Comparator: block (InputInterface.SetFlag = '1' or InputInterface.BranchInstructionFlag = '1') is
	Comparator: block is

		opA, opB: std_logic_vector(31 downto 0);
		
	begin

		opA <= Data1;

		opB <= resize(signed(InputInterface.IMM, 32)) when InputInterface.SetFlag = '1' and InputInterface.SetImmediate = '1' and InputInterface.SetUnsigned = '0' else 
		opB <= resize(unsigned(InputInterface.IMM, 32)) when InputInterface.SetFlag = '1' and InputInterface.SetImmediate = '1' and InputInterface.SetUnsigned = '1' else 
			   x"00000000" when InputInterface.BranchInstructionFlag = '1' and InputInterface.BranchAroundZero = '1' else
			   Data2; 

		ComparatorFlags(2) <= '1' when opA > opB else '0';
		ComparatorFlags(1) <= '1' when opA = opB else '0';
		ComparatorFlags(0) <= '1' when opA < opB else '0';
		
	end block Comparator;

	-- Mask off comparator flags with branch modes from previous stage and determine branch flag
	OutputInterface.BranchTakeFlag <= '1' when (ComparatorFlags and InputInterface.BranchInstructionModes) /= "000" and InputInterface.BranchInstructionFlag = '1' else '0';

	-- Set branch address asynchronously (and branch taken flag (above) as well) TODO: Make synchrounous
	OutputInterface.BranchAddress <= ALUResult;


	--ALU: block (InputInterface.ShifterFlag = '0') is
	ALU: block is

		tempResult, opA, opB: std_logic_vector(32 downto 0);
		
	begin

		opA <= InputInterface.Data1(31) & InputInterface.Data1;

		opB <= resize(signed(InputInterface.IMM, 32)) when InputInterface.MemoryAccessFlag = '1' or InputInterface.ArithmeticExtendFlag = '1' else
			   resize(unsigned(InputInterface.IMM, 32)) when  else
			   InputInterface.Data2(31) & InputInterface.Data2;

		tempResult <= opA - opB when InputInterface.ALUOP = "001" else
					  opA and opB when InputInterface.ALUOP = "010" else
					  opA or opB when InputInterface.ALUOP = "011" else
					  opA nor opB when InputInterface.ALUOP = "100" else
					  opA xor opB when InputInterface.ALUOP = "101" else
					  opA + opB;

		ALUResult <= tempResult(31 downto 0);

		ALUFlags(3) <= ALUResult(31) when ALUOP = "000" or ALUOP = "001" else '0';
		ALUFlags(2) <= '1' when tempResult(31 downto 0) = x"00000000" else '0';
		ALUFlags(1) <= tempResult(32) when ALUOP = "000" or ALUOP = "001" else '0';
		ALUFlags(0) <= '1' when (ALUOP = "000" or ALUOP = "001") = '1' and (opA(31) = opB(31)) and (ALUResult(31) /= opA(31) or ALUResult(31) /= opB(31)) else '0'; 

	end block ALU;


	--Shifter: block (InputInterface.ShifterFlag = '1') is
	Shifter: block is

		opA, opB: std_logic_vector(31 downto 0);
		
	begin

		opA <= unsigned(InputInterface.Data1) when InputInterface.ShifterArithmetic = '0' else signed(InputInterface.Data1);

		-- Constrains shift amount to 5 least significative bits because any shift beyond 32 (2^5) is irrelevant for 32 bit data 
		opB <= unsigned(InputInterface.Data2(4 downto 0)) when InputInterface.ShifterVariable = '1' else
			   unsigned(InputInterface.IMM(4 downto 0));

		ShifterData <= shift_left(opA, to_integer(opB)) when InputInterface.ShifterLeft = '1' else
					   shift_right((opA), to_integer(opB));
	
	end block Shifter;


	DataAsync <= ShifterData when InputInteface.ShifterFlag = '1' else
				 x"00000000" when SetFlag = '1' and ComparatorLessThanFlag = '0' else
				 x"00000001" when SetFlag = '1' and ComparatorLessThanFlag = '1' else
				 InputInterface.IMM & x"0000" when InputInterface.LUIFlag = '1' else
				 ALUData;


	-- Pipeline Registers
	PipelineRegisters: process(Clock, Reset) begin

		if Reset = '1' then

			-- Memory Access stage data
			OutputInterface.ALUResult <= (others => '0');
			OutputInterface.RegBankPassthrough <= (others => '0');

			-- Memory Access stage control signals
			OutputInterface.LUIFlag <= '0';
			OutputInterface.MemoryAccessFlag <= '0';
			OutputInterface.MemoryAccessLoad <= '0';
			OutputInterface.MemoryAccessUnsigned <= '0';
			OutputInterface.MemoryAccessGranularity <= "00";

			-- Writeback stage control signals
			OutputInterface.WritebackEnable <= '0';
			OutputInterface.WritebackReg <= "00000";

		elsif rising_edge(Clock) then

			-- Memory Access stage data
			OutputInterface.ALUResult <= DataAsync;
			OutputInterface.RegBankPassthrough <= InputInterface.Data1;

			-- Memory Access stage control signals
			OutputInterface.MemoryAccessFlag <= InputInterface.MemoryAccessFlag;
			OutputInterface.MemoryAccessLoad <= InputInterface.MemoryAccessLoad;
			OutputInterface.MemoryAccessUnsigned <= InputInterface.MemoryAccess;
			OutputInterface.MemoryAccessGranularity <= InputInterface.MemoryAccessGranularity;

			-- Writeback stage control signals
			OutputInterface.LUIFlag <= InputInterface.LUIFlag;
			OutputInterface.WritebackReg <= InputInterface.WritebackReg;
			OutputInterface.WritebackEnable <= InputInterface.WritebackEnable;

		end if;

	end process PipelineRegisters;
	
end architecture RTL;
