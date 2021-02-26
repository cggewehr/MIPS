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
--               v0.1 - Gewehr: Implemented Arithmetic -> Arithmetic forwarding
--------------------------------------------------------------------------------
-- TODO        : Implement MUL/DIV with Multiplier/Divider in another clock domain
--               Implement Multiply-and-Accumulate instructions
--               Implement Leading Zeroes and Leading Ones count instructions
--               Implement Load -> Arithmetic forwarding
--               Implement Trap instructions using registered comparator flags
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


entity ExecuteStage is

	generic(
		EnableForwarding: boolean := True
	);
	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		Stall: in std_logic;
		Flush: in std_logic;
		Except: out std_logic;

		InputInterface: in ExecuteInput;  -- Defined in MIPS_PKG
		OutputInterface: inout ExecuteOutput  -- Defined in MIPS_PKG

	);
	
end entity ExecuteStage;


architecture RTL of ExecuteStage is

	-- Forwarding Unit signals
	signal DataA: std_logic_vector(31 downto 0);
	signal DataB: std_logic_vector(31 downto 0);

	-- Comparator signals
	signal ComparatorFlags: std_logic_vector(2 downto 0);
	signal ComparatorFlagsRegistered: std_logic_vector(2 downto 0);
	alias ComparatorGreatedThanFlag: std_logic is ComparatorFlags(2);
	alias ComparatorEqualFlag: std_logic is ComparatorFlags(1);
	alias ComparatorLessThanFlag: std_logic is ComparatorFlags(0);
	signal ComparatorMasked: std_logic_vector(2 downto 0);
	signal ComparatorHit: std_logic;

	-- ALU signals
	signal ALUData: std_logic_vector(31 downto 0);
	signal ALUFlags: std_logic_vector(3 downto 0);  -- Negative, Zero, Carry, Overflow

	-- Shifter signals
	signal ShifterData: std_logic_vector(31 downto 0);
	
	-- Data out MUX
	signal DataAsync: std_logic_vector(31 downto 0);

	signal BranchOverride: std_logic;
	signal BranchStateEnable: std_logic;
	
begin

	-- TODO: Implement Load -> Arithmetic forwarding
	ForwardingUnit: if EnableForwarding generate

		-- Forward RS (prioritizes forwarding from EX/MEM barrier)
		--DataA <= OutputInterface.ALUResult when (OutputInterface.WritebackReg = InputInterface.RS and OutputInterface.WritebackEnable = '1' and OutputInterface.WritebackReg /= "00000") else  -- Forward from EX/MEM barrier
		DataA <= OutputInterface.ALUResult when (OutputInterface.WritebackReg = InputInterface.RS and OutputInterface.WritebackEnable = '1' and OutputInterface.MemoryAccessFlag = '0' and OutputInterface.WritebackReg /= "00000") else  -- Forward from EX/MEM barrier
				 InputInterface.WBStageData when (InputInterface.WBStageReg = InputInterface.RS and InputInterface.WBStageEnable = '1' and InputInterface.WBStageReg /= "00000") else  -- Forward from MEM/WB barrier
				 InputInterface.Data1;  -- As read from RegBank (no forwarding necessary)

		-- Forward RT (prioritizes forwarding from EX/MEM barrier)
		DataB <= OutputInterface.ALUResult when (OutputInterface.WritebackReg = InputInterface.RT and OutputInterface.WritebackEnable = '1' and OutputInterface.MemoryAccessFlag = '0' and OutputInterface.WritebackReg /= "00000") else  -- Forward from EX/MEM barrier
				 InputInterface.WBStageData when (InputInterface.WBStageReg = InputInterface.RT and InputInterface.WBStageEnable = '1' and InputInterface.WBStageReg /= "00000") else  -- Forward from MEM/WB barrier
				 InputInterface.Data2;  -- As read from RegBank (no forwarding necessary)

	end generate ForwardingUnit;

	-- else -- ( "else" keyword in "if generate" construct only supported in VHDL-2008)
	NoForwardingUnit: if not EnableForwarding generate  -- VHDL-1993 compatible

		DataA <= InputInterface.Data1;
		DataB <= InputInterface.Data2;

	--end generate ForwardingUnit;  -- ( "else" keyword in "if generate" construct only supported in VHDL-2008)
	end generate NoForwardingUnit;  -- VHDL-1993 compatible


	--Comparator: block (InputInterface.SetFlag = '1' or InputInterface.BranchInstructionFlag = '1') is
	Comparator: block is

		signal opA, opB: std_logic_vector(31 downto 0);
		
	begin

		--opA <= InputInterface.Data1;
		opA <= DataA;

		opB <= std_logic_vector(resize(signed(InputInterface.IMM), 32)) when InputInterface.SetFlag = '1' and InputInterface.SetImmediate = '1' and InputInterface.SetUnsigned = '0' else 
		       std_logic_vector(resize(unsigned(InputInterface.IMM), 32)) when InputInterface.SetFlag = '1' and InputInterface.SetImmediate = '1' and InputInterface.SetUnsigned = '1' else 
			   x"00000000" when InputInterface.BranchInstructionFlag = '1' and InputInterface.BranchInstructionAroundZero = '1' else
			   --InputInterface.Data2; 
			   DataB; 

		ComparatorFlags(2) <= '1' when opA > opB else '0';
		ComparatorFlags(1) <= '1' when opA = opB else '0';
		ComparatorFlags(0) <= '1' when opA < opB else '0';
		
		ComparatorMasked <= ComparatorFlags and InputInterface.ComparatorMasks;
		
		ComparatorHit <= ComparatorMasked(2) or ComparatorMasked(1) or ComparatorMasked(0);

		process(Clock, Reset) begin

			if Reset = '1' then
				ComparatorFlagsRegistered <= (others => '0');

			elsif rising_edge(Clock) then

				if Flush = '1' then
					ComparatorFlagsRegistered <= (others => '0');
				else
					ComparatorFlagsRegistered <= ComparatorFlags;
				end if;

			end if;

		end process;
		
	end block Comparator;


	--ALU: block (InputInterface.ShifterFlag = '0') is
	ALU: block is

		signal tempResult, opA, opB: std_logic_vector(32 downto 0);
		--signal tempResult, opA, opB: signed(32 downto 0);
		
	begin

		--opA <= InputInterface.Data1(31) & InputInterface.Data1 when InputInterface.BranchInstructionFlag = '0' and InputInterface.JumpFromImmediate = '0' else
		opA <= DataA(31) & DataA;
		       --InputInterface.IncrementedPC(31) & InputInterface.IncrementedPC;

		--opB <= std_logic_vector(resize(signed(InputInterface.IMM), 33)) when InputInterface.MemoryAccessFlag = '1' or InputInterface.ArithmeticExtendFlag = '1' or InputInterface.BranchInstructionFlag = '1' else
		opB <= std_logic_vector(resize(signed(InputInterface.IMM), 33)) when InputInterface.MemoryAccessFlag = '1' or (InputInterface.ArithmeticImmediateFlag = '1' and InputInterface.ArithmeticUnsignedFlag = '0') else
			   std_logic_vector(resize(unsigned(InputInterface.IMM), 33)) when InputInterface.ArithmeticImmediateFlag = '1' and InputInterface.ArithmeticUnsignedFlag = '1' else
			   --std_logic_vector(resize(signed(InputInterface.IMM), 31)) & "00" when InputInterface.JumpFromImmediate = '1' or InputInterface.BranchInstructionFlag = '1' else  Jump address computation moved to Decode stage
			   --std_logic_vector(resize(signed(InputInterface.IMM), 33)) when InputInterface.JumpFromImmediate = '1' else
			   --InputInterface.Data2(31) & InputInterface.Data2;
			   DataB(31) & DataB;

		tempResult <= std_logic_vector(unsigned(opA) - unsigned(opB)) when InputInterface.ALUOP = "001" else
					  opA and opB when InputInterface.ALUOP = "010" else
					  opA or opB when InputInterface.ALUOP = "011" else
					  opA nor opB when InputInterface.ALUOP = "100" else
					  opA xor opB when InputInterface.ALUOP = "101" else
					  std_logic_vector(unsigned(opA) + unsigned(opB));

		ALUData <= std_logic_vector(tempResult(31 downto 0));

		ALUFlags(3) <= ALUData(31) when InputInterface.ALUOP = "000" or InputInterface.ALUOP = "001" else '0';
		ALUFlags(2) <= '1' when tempResult(31 downto 0) = x"00000000" else '0';
		ALUFlags(1) <= tempResult(32) when InputInterface.ALUOP = "000" or InputInterface.ALUOP = "001" else '0';
		ALUFlags(0) <= '1' when (InputInterface.ALUOP = "000" or InputInterface.ALUOP = "001") and (opA(31) = opB(31)) and (ALUData(31) /= opA(31) or ALUData(31) /= opB(31)) else '0'; 

	end block ALU;


	--Shifter: block (InputInterface.ShifterFlag = '1') is
	Shifter: block is

		signal opA: std_logic_vector(31 downto 0);
		signal opB: unsigned(4 downto 0);
		
	begin

		--opA <= InputInterface.Data1;
		opA <= DataA;

		-- Constrains shift amount to 5 least significative bits because any shift beyond 32 (2^5) is irrelevant for 32 bit data 
		--opB <= unsigned(InputInterface.Data2(4 downto 0)) when InputInterface.ShifterVariable = '1' else
		opB <= unsigned(DataB(4 downto 0)) when InputInterface.ShifterVariable = '1' else
			   unsigned(InputInterface.IMM(4 downto 0));

		ShifterData <= std_logic_vector(shift_left(unsigned(opA), to_integer(opB))) when InputInterface.ShifterLeft = '1' and InputInterface.ShifterArithmetic = '0' else
		               std_logic_vector(shift_left(signed(opA), to_integer(opB))) when InputInterface.ShifterLeft = '1' and InputInterface.ShifterArithmetic = '1' else
					   std_logic_vector(shift_right(unsigned(opA), to_integer(opB)));
	
	end block Shifter;


	DataAsync <= ShifterData when InputInterface.ShifterFlag = '1' else
				 x"00000000" when InputInterface.SetFlag = '1' and ComparatorHit = '0' else
				 x"00000001" when InputInterface.SetFlag = '1' and ComparatorHit = '1' else
				 InputInterface.IMM & x"0000" when InputInterface.LUIFlag = '1' else
				 ALUData;


	BranchComputation: block is begin

		-- Mask off comparator flags with branch modes from previous stage and determine branch flag
		--OutputInterface.BranchTakeFlag <= '1' when (InputInterface.JumpFromImmediate = '1') or ((ComparatorFlags and InputInterface.BranchInstructionModes) /= "000" and InputInterface.BranchInstructionFlag = '1') else '0';
		--OutputInterface.BranchTakeFlag <= '1' when (InputInterface.JumpFromImmediate = '1') or (InputInterface.BranchInstructionFlag = '1' and ComparatorHit = '1') else '0';

		-- Set branch address asynchronously (and branch taken flag (above) as well) TODO: Make synchrounous
		--OutputInterface.BranchAddress <= ALUData when InputInterface.JumpFromImmediate = '0' else
		--                                 InputInterface.Data2;  -- Set in Decode stage

		BranchOverride <= '1' when InputInterface.BranchInstructionFlag = '1' and InputInterface.JumpFromImmediate = '0' and (InputInterface.BranchWasTaken xor ComparatorHit) = '1' else '0';
		BranchStateEnable <= '1' when InputInterface.BranchInstructionFlag = '1' and InputInterface.JumpFromImmediate = '0' else '0'; 


	end block BranchComputation;


	-- Pipeline Registers
	PipelineRegisters: process(Clock, Reset) begin

		if Reset = '1' then

			Except <= '0';
			
			-- Branch control to Decode stage
			OutputInterface.BranchOverride <= '0';
			OutputInterface.BranchStateEnable <= '0';

			-- Memory Access stage data
			OutputInterface.ALUResult <= (others => '0');
			OutputInterface.RegBankPassthrough <= (others => '0');
			OutputInterface.RT <= (others => '0');

			-- Memory Access stage control signals
			--OutputInterface.LUIFlag <= '0';
			OutputInterface.MemoryAccessFlag <= '0';
			OutputInterface.MemoryAccessLoad <= '0';
			OutputInterface.MemoryAccessUnsigned <= '0';
			OutputInterface.MemoryAccessGranularity <= "00";

			-- Writeback stage control signals
			OutputInterface.WritebackEnable <= '0';
			OutputInterface.WritebackReg <= "00000";

		elsif rising_edge(Clock) then

			if Stall = '0' then
			
			    -- Branch control to Decode stage
                OutputInterface.BranchOverride <= BranchOverride;
                OutputInterface.BranchStateEnable <= BranchStateEnable;

				-- Memory Access stage data
				OutputInterface.ALUResult <= DataAsync;
				--OutputInterface.RegBankPassthrough <= InputInterface.Data2;
				OutputInterface.RegBankPassthrough <= DataB;
				OutputInterface.RT <= InputInterface.RT;  -- to MEM stage forwarding

				-- Memory Access stage control signals
				if Flush = '0' then
					OutputInterface.MemoryAccessFlag <= InputInterface.MemoryAccessFlag;
				else
					OutputInterface.MemoryAccessFlag <= '0';
				end if;
				OutputInterface.MemoryAccessLoad <= InputInterface.MemoryAccessLoad;
				OutputInterface.MemoryAccessUnsigned <= InputInterface.MemoryAccessUnsigned;
				OutputInterface.MemoryAccessGranularity <= InputInterface.MemoryAccessGranularity;

				-- Writeback stage control signals
				--OutputInterface.LUIFlag <= InputInterface.LUIFlag;
				OutputInterface.WritebackReg <= InputInterface.WritebackReg;
				if Flush = '0' then
					OutputInterface.WritebackEnable <= InputInterface.WritebackEnable;
				else
					OutputInterface.WritebackEnable <= '0';
				end if;

			end if;

		end if;

	end process PipelineRegisters;
	
end architecture RTL;
