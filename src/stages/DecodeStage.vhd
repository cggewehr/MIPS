--------------------------------------------------------------------------------
-- Title       : DecodeStage
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : DecodeStage.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Implements Decode stage in the 5 stage pipeline
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Gewehr: Initial implementation
--             : v0.1 - Gewehr: Changed RegBank reads from async to falling edge triggered
--------------------------------------------------------------------------------
-- TODO        : Use shifter info for LUI instruction, so that a specific flag is not needed anymore
--               Implement branch decision at Decode stage
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


entity DecodeStage is

	generic(
		BranchPredictorDepth: integer := 2;
		BranchDelaySlot: boolean := False
	);

	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		Stall: in std_logic;
		Flush: in std_logic;
		Except: out std_logic;
		
		PipelineStall: out std_logic_vector(0 to 3);
		PipelineFlush: out std_logic_vector(0 to 3);

		InputInterface: in DecodeInput;  -- Defined in MIPS_PKG
		OutputInterface: inout DecodeOutput  -- Defined in MIPS_PKG

	);
	
end entity DecodeStage;


architecture RTL of DecodeStage is

	type RegisterBank_t is array(1 to 31) of std_logic_vector(31 downto 0);
	signal RegisterBank: RegisterBank_t;

	-- Branch Predictor
	signal BranchTakeFlag: std_logic;

	-- Defines fields from fetched instruction for R type instructions
	alias OPCODE: std_logic_vector(5 downto 0) is InputInterface.Instruction(31 downto 26); 
    alias RS: std_logic_vector(4 downto 0) is InputInterface.Instruction(25 downto 21);
    alias RT: std_logic_vector(4 downto 0) is InputInterface.Instruction(20 downto 16);
    alias RD: std_logic_vector(4 downto 0) is InputInterface.Instruction(15 downto 11);
    alias SHAMT: std_logic_vector(4 downto 0) is InputInterface.Instruction(10 downto 6);
    alias FUNCT: std_logic_vector(5 downto 0) is InputInterface.Instruction(5 downto 0);

    -- Defines fields from fetched instruction for I type instructions
    alias IMM: std_logic_vector(15 downto 0) is InputInterface.Instruction(15 downto 0);

    -- Defines fields from fetched instruction for J type instructions
    alias BASE: std_logic_vector(25 downto 0) is InputInterface.Instruction(25 downto 0);

    -- Asynchronous result of comparisons to OPCODE field
    signal RTypeFlagAsync: std_logic;
    signal ITypeFlagAsync: std_logic;
    --signal JTypeFlagAsync: std_logic;  -- REPLACED BY "JumpUnconditionalFlagAsync", does same thing

    --ALU
    signal SetFlagAsync: std_logic;
    signal SetImmediateAsync: std_logic;
    signal SetUnsignedAsync: std_logic;
    signal LUIFlagAsync: std_logic;

    signal ALUOPAsync: std_logic_vector(2 downto 0);
    signal ArithmeticExtendFlagAsync: std_logic;
    signal ArithmeticImmediateFlagAsync: std_logic;
    signal ArithmeticUnsignedFlagAsync: std_logic;

    -- Shifter flags
    signal ShifterFlagAsync: std_logic;
    signal ShifterVariableAsync: std_logic;
    signal ShifterArithmeticAsync: std_logic;
    signal ShifterLeftAsync: std_logic;

    -- Asynchronous flags for branch instructions
    signal BranchInstructionFlagAsync: std_logic;
    --signal BranchInstructionModesAsync: std_logic_vector(2 downto 0);
    signal BranchInstructionLinkAsync: std_logic;  -- SHARED WITH "JumpUnconditionalLinkAsync"
    signal BranchInstructionAroundZeroAsync: std_logic;
    signal ComparatorMasksAsync: std_logic_vector(2 downto 0);

    -- Asynchronous flags for jump instructions
    signal JumpUnconditionalFlagAsync: std_logic;
    --signal JumpUnconditionalLinkAsync: std_logic;  SHARED WITH "BranchInstructionLinkAsync"
    signal JumpFromImmediateAsync: std_logic;

    -- Asynchronous flags for memory access instructions
    signal MemoryAccessFlagAsync: std_logic;
    signal MemoryAccessLoadAsync: std_logic;
    signal MemoryAccessGranularityAsync: std_logic_vector(1 downto 0);
    signal MemoryAccessUnsignedAsync: std_logic;

    -- Asynchronous flags for writeback control
    signal WritebackRegAsync: std_logic_vector(4 downto 0);
    signal WritebackEnableAsync: std_logic;

    -- Asynchronous read from read bank temporaries
    signal RegData1Async: std_logic_vector(31 downto 0);
    signal RegData2Async: std_logic_vector(31 downto 0);

    -- Data read from RegBank
    signal Data1: std_logic_vector(31 downto 0);
    signal Data2: std_logic_vector(31 downto 0);

begin

	-- Reads from Register Bank and forwards writeback data
	--RegBankForwardRead: if EnableForwarding generate

	--	RegData1Async <= (others => '0') when RS = "00000" else 
	--					 RegisterBank(to_integer(unsigned(RS))) when RS /= InputInterface.WritebackReg else 
	--					 InputInterface.WritebackData;

	--	RegData2Async <= (others => '0') when RT = "00000" else 
	--					 RegisterBank(to_integer(unsigned(RT))) when RT /= InputInterface.WritebackReg else 
	--					 InputInterface.WritebackData;

	--end generate RegBankForwardRead;

	---- Reads from Register Bank and dont forward writeback data
	--RegBankNoForwardRead: if not EnableForwarding generate

	--	RegData1Async <= (others => '0') when RS = "00000" or RS = "UUUUU" else RegisterBank(to_integer(unsigned(RS)));
	--	--RegData1Async <= RegisterBank(to_integer(unsigned(RS))) when RS /= "00000" else (others => '0');
	--	RegData2Async <= (others => '0') when RT = "00000" or RT = "UUUUU" else RegisterBank(to_integer(unsigned(RT)));
	--	--RegData2Async <= RegisterBank(to_integer(unsigned(RT))) when RT /= "00000" else (others => '0');

	--end generate RegBankNoForwardRead;

	BranchPredictor: block is

		signal BranchPredictorState: std_logic_vector(BranchPredictorDepth - 1 downto 0);

		--signal BranchTakeFlag: std_logic;  NOW DECLARED @ ENTITY
		signal BranchAddress: std_logic_vector(31 downto 0);
		signal BranchPCSaved: std_logic_vector(31 downto 0);

	begin

		BranchTakeFlag <= BranchPredictorState(BranchPredictorDepth - 1) when BranchInstructionFlagAsync = '1' else
						  '1' when JumpFromImmediateAsync = '1' or InputInterface.BranchOverride = '1' else 
						  '0';

		OutputInterface.BranchTakeFlag <= BranchTakeFlag;

		--OutputInterface.BranchAddress <= InputInterface.IncrementedPC(31 downto 28) & BASE & "00" when JumpFromImmediateAsync = '1' else  -- J or JAL instructions
		BranchAddress <= BranchPCSaved when InputInterface.BranchOverride = '1' else
						 InputInterface.IncrementedPC(31 downto 28) & BASE & "00" when JumpFromImmediateAsync = '1' else  -- J or JAL instructions
						 std_logic_vector(signed(InputInterface.IncrementedPC) + (resize(signed(IMM), 30) & "00"));  -- when BranchInstructionFlagAsync = '1' else  -- Other branch instructions

        OutputInterface.BranchAddress <= BranchAddress;

		BranchControlProc: process(Clock, Reset) begin

			if Reset = '1' then

				BranchPredictorState <= (BranchPredictorDepth - 1 => '0', others => '1');  -- Inits to weak not taken
				BranchPCSaved <= (others => '0');

			elsif rising_edge(Clock) then

				-- Updates branch predictor state
				-- Branch wrongfully taken
				if OutputInterface.BranchWasTaken = '1' and InputInterface.BranchOverride = '1' and InputInterface.BranchStateEnable = '1' then
					BranchPredictorState <= std_logic_vector(unsigned(BranchPredictorState) - 1);

				-- Branch wrongfully not taken
				elsif OutputInterface.BranchWasTaken = '0' and InputInterface.BranchOverride = '1' and InputInterface.BranchStateEnable = '1' then
					BranchPredictorState <= std_logic_vector(unsigned(BranchPredictorState) + 1);

				-- Branch rightfully taken
				elsif OutputInterface.BranchWasTaken = '1' and InputInterface.BranchOverride = '0' and InputInterface.BranchStateEnable = '1' then

					if BranchPredictorState /= (BranchPredictorDepth - 1 downto 0 => '1') then
						BranchPredictorState <= std_logic_vector(unsigned(BranchPredictorState) + 1);
					end if;

				-- Branch rightfully not taken
				elsif OutputInterface.BranchWasTaken = '0' and InputInterface.BranchOverride = '0' and InputInterface.BranchStateEnable = '1' then 

					if BranchPredictorState /= (BranchPredictorDepth - 1 downto 0 => '0') then
						BranchPredictorState <= std_logic_vector(unsigned(BranchPredictorState) - 1);
					end if;

				end if;

				-- Saves IncrememtedPC if branch is taken or computed branch address if branch is not taken
				if BranchInstructionFlagAsync = '1' and BranchPredictorState(BranchPredictorDepth - 1) = '1' then
					BranchPCSaved <= InputInterface.IncrementedPC;

				elsif BranchInstructionFlagAsync = '1' and BranchPredictorState(BranchPredictorDepth - 1) = '0' then
					BranchPCSaved <= BranchAddress;

				end if;

			end if;

		end process BranchControlProc;

	end block BranchPredictor;


	-- Reads from Register Bank @ clock falling edge
	--RegBankRead: process(Clock, Reset) begin
	RegBankRead: process(Reset, RS, RT, RegisterBank) begin

		if Reset = '1' or RS = "UUUUU" or RT = "UUUUU" then

			Data1 <= (others => '0');
			Data2 <= (others => '0');

		--elsif falling_edge(Clock) then
		else
            
            --Data1 <= RegisterBank(to_integer(unsigned(RS))) when RS /= "00000" else (others => '0');
            if RS = "00000" then
                Data1 <= (others => '0');
            else
                Data1 <= RegisterBank(to_integer(unsigned(RS)));
            end if;
            
            --Data2 <= RegisterBank(to_integer(unsigned(RT))) when RT /= "00000" else (others => '0');
            if RT = "00000" then 
                Data2 <= (others => '0');
            else
                Data2 <= RegisterBank(to_integer(unsigned(RT)));
            end if;
			
		end if;

	end process RegBankRead;


	-- Writes to Register Bank
	RegBankWrite: process(Clock, Reset) begin

		if Reset = '1' then
			RegisterBank <= (others => (others => '0'));

		--elsif rising_edge(Clock) then
		elsif falling_edge(Clock) then

			if InputInterface.WritebackReg /= "00000" then

				if InputInterface.WritebackEnable = '1' then
					RegisterBank(to_integer(unsigned(InputInterface.WritebackReg))) <= InputInterface.WritebackData;

				end if;

			end if;

			-- TODO: Write PC + 4 to $31 if (BGEZAL, BLTZAL, JAL, JRAL). (Implement branch address computation on 2nd stage first)

		end if;

	end process;


	-- Flags instruction types
	RTypeFlagAsync <= '1' when OPCODE = "000000" else '0';
	--JTypeFlagAsync <= '1' when OPCODE = "000010" or OPCODE = "000011" else '0';  -- J or JAL instructions
	--ITypeFlagAsync <= RTypeFlagAsync nand JTypeFlagAsync;
	ITypeFlagAsync <= RTypeFlagAsync nand JumpUnconditionalFlagAsync;  -- "JumpUnconditionalFlagAsync" is defined below, and is true when (J, JAL, JALR, JR) instructions are fetched


	-- Flags a LUI instruction. Needs a specific flag because shifting behaviour is unique
	LUIFlagAsync <= '1' when OPCODE = "001111" else '0';

	-- Flags (ADDIU, ADDU, SUBU, ANDI, ORI, XORI)  TODO: Add MULTU when implementing multiplicatiton/division instructions
	--ArithmeticUnsignedFlagAsync <= '1' when OPCODE = "001001" or (OPCODE = "000000" and (FUNCT = "100001" or FUNCT = "100011")) or OPCODE = "001100" or OPCODE = "001101" or OPCODE = "001110" else '0';
	-- Flags (ANDI, ORI, XORI)  TODO: Add MULTU when implementing multiplicatiton/division instructions
	ArithmeticUnsignedFlagAsync <= '1' when  OPCODE = "001100" or OPCODE = "001101" or OPCODE = "001110" else '0';

	-- (ADDI, ADDIU, ANDI, ORI, XORI)
	ArithmeticImmediateFlagAsync <= '1' when OPCODE = "001000" or OPCODE = "001001" or OPCODE = "001100" or OPCODE = "001101" or OPCODE = "001110" else '0';

	-- (ADDI, ADDIU, SLTI, SLTIU)
	ArithmeticExtendFlagAsync <= '1' when OPCODE = "001000" or OPCODE = "001001" or OPCODE = "001010" or OPCODE = "001011" else '0';

	-- Arithmetical operations to be performed by the ALU, except for sets (uses Comparator module) and shifts (uses Shifter module)
	ALUOPAsync <= "001" when OPCODE = "000000" and (FUNCT = "100010" or FUNCT = "100011") else   -- SUBTRACTION (SUB, SUBU)
				  "010" when (OPCODE = "000000" and FUNCT = "100100") or OPCODE = "001100" else  -- BITWISE AND (AND, ANDI)
				  "011" when (OPCODE = "000000" and FUNCT = "100101") or OPCODE = "001101" else  -- BITWISE OR (OR, ORI)
			 	  "100" when (OPCODE = "000000" and FUNCT = "100111") else                       -- BITWISE NOR (NOR)
				  "101" when (OPCODE = "000000" and FUNCT = "100110") or OPCODE = "001110" else  -- BITWISE XOR (XOR, XORI)
				  "000";                                                                         -- ADDITION (ADD, ADDI, ADDIU, LW, SW, ...) (Adds and anything else)


	-- (SLL, SLLV, SRA, SRAV, SRL, SRLV)
	ShifterFlagAsync <= '1' when (OPCODE = "000000" and (SHAMT /= "00000")) or OPCODE = "000100" or OPCODE = "000011" or OPCODE = "000111" or OPCODE = "000010" or OPCODE = "000110" else '0';

	-- (SLLV, SRAV, SRLV)
	ShifterVariableAsync <= '1' when OPCODE = "000100" or OPCODE = "000111" or OPCODE = "000110" else '0';

	-- (SRA, SRAV);
	ShifterArithmeticAsync <= '1' when OPCODE = "000011" or OPCODE = "000111" else '0';

	-- (SLL, SLLV)
	ShifterLeftAsync <= '1' when (OPCODE = "000000" and (SHAMT /= "00000")) or OPCODE = "000100" else '0';


	-- Flags branch instructions (BEQ, BGEZ, BGEZAL, BGTZ, BLTZ, BLTZAL, BNE) (OPCODEs are taken from opencores.org/projects/plasma/opcodes)
	BranchInstructionFlagAsync <= '1' when OPCODE = "000100" or OPCODE = "000001" or OPCODE = "000111" or OPCODE = "000110" or OPCODE = "000101" else '0';
	
	-- Save PC on return register for branch-and-link type instructions (BGEZAL, BLTZAL, JAL, JRAL)
	BranchInstructionLinkAsync <= '1' when (OPCODE = "000001" and RT = "10001") or (OPCODE = "000001" and RT = "10000") or OPCODE = "000011" or (OPCODE = "000000" and RT = "00000" and SHAMT = "00000" and FUNCT = "001001") else '0'; 

	-- Always '1' except on BEQ
	BranchInstructionAroundZeroAsync <= '0' when OPCODE = "000100" or BranchInstructionFlagAsync = '0' else '1';

	-- Take branch if Greater Then. (BGEZ, BGEZAL, BGTZ, BNE) instructions
	--BranchInstructionModesAsync(2) <= '1' when (OPCODE = "000001" and RT = "00001") or (OPCODE = "000001" and RT = "10001") or (OPCODE = "000111" and RT = "00000") or OPCODE = "000101" else '0';

	-- Take branch if Equal. (BEQ, BGEZ, BGEZAL)
	--BranchInstructionModesAsync(1) <= '1' when OPCODE = "000100" or (OPCODE = "000001" and RT = "00001") or (OPCODE = "000001" and RT = "10001") else '0';

	-- Take branch if Lesser Then. (BLTZ, BLTZAL, BNE)
	--BranchInstructionModesAsync(0) <= '1' when (OPCODE = "000001" and RT = "00000") or (OPCODE = "000001" and RT = "10000") or OPCODE = "000101" else '0';

    -- Branch if Greater Then (BGEZ, BGEZAL, BGTZ, BNE) instructions
    ComparatorMasksAsync(2) <= '1' when (OPCODE = "000001" and RT = "00001") or (OPCODE = "000001" and RT = "10001") or (OPCODE = "000111" and RT = "00000") or OPCODE = "000101" else '0';

	-- Branch if Equal (BEQ, BGEZ, BGEZAL) instructions
	ComparatorMasksAsync(1) <= '1' when OPCODE = "000100" or (OPCODE = "000001" and RT = "00001") or (OPCODE = "000001" and RT = "10001") else '0';

    -- Branch if Lesser Then (BLTZ, BLTZAL, BNE) or Set Less Than instructions (SLTI, SLT)
	ComparatorMasksAsync(0) <= '1' when (OPCODE = "000001" and RT = "00000") or (OPCODE = "000001" and RT = "10000") or OPCODE = "000101" or SetFlagAsync = '1' else '0';

	-- Flags set instructions (SLT, SLTU, SLTI, SLTIU)
	SetFlagAsync <= '1' when (OPCODE = "000000" and (FUNCT = "101010" or FUNCT = "101011")) or OPCODE = "001010" or OPCODE = "001011" else '0';

	-- (SLTI, SLTIU)
	SetImmediateAsync <= '1' when OPCODE = "001010" or OPCODE = "001011" else '0';

	-- (SLTU, SLTIU)
	SetUnsignedAsync <= '1' when (OPCODE = "000000" and FUNCT = "101011") or OPCODE = "001011" else '0';


	-- J, JAL, JALR, JR instructions
	JumpUnconditionalFlagAsync <= '1' when OPCODE = "000010" or OPCODE = "000011" or (OPCODE = "000000" and RT = "00000" and SHAMT = "00000" and (FUNCT = "001001" or FUNCT = "001000")) else '0';

	-- J or JAL instructions
	JumpFromImmediateAsync <= '1' when OPCODE = "000010" or OPCODE = "000011" else '0';


	-- (LB, LBU, LH, LHU, LW, SB, SH, SW) 
	MemoryAccessFlagAsync <= '1' when OPCODE = "100000" or OPCODE = "100100" or OPCODE = "100001" or OPCODE = "100101" or OPCODE = "100011" or OPCODE = "101000" or OPCODE = "101001" or OPCODE = "101011" else '0';

	-- (LB, LBU, LH, LHU, LW)
	MemoryAccessLoadAsync <= '1' when OPCODE = "100000" or OPCODE = "100100" or OPCODE = "100001" or OPCODE = "100101" or OPCODE = "100011" else '0';

	-- "00" for word (LW, SW), "01" for half-word (LH, LHU, SH), "10" for byte (LB, LBU, SB)
	MemoryAccessGranularityAsync <= "00" when OPCODE = "100011" or OPCODE = "101011" else
									"01" when OPCODE = "100001" or OPCODE = "100101" or OPCODE = "101001" else
									"10";

	-- (LBU, LHU)
	MemoryAccessUnsignedAsync <= '1' when OPCODE = "100100" or OPCODE = "100101" else '0';


	-- 
	--WritebackEnableAsync <= '1' when (RTypeFlagAsync = '1' and InputInterface.Instruction /= x"00000000" and FUNCT /= "01000") or ArithmeticImmediateFlagAsync = '1' or (MemoryAccessFlagAsync = '1' and MemoryAccessLoadAsync = '1') or BranchInstructionLinkAsync = '1' or LUIFlagAsync = '1' else '0';
	WritebackEnableAsync <= '1' when (RTypeFlagAsync = '1' and InputInterface.Instruction /= x"00000000" and FUNCT /= "001000") or ArithmeticImmediateFlagAsync = '1' or (MemoryAccessFlagAsync = '1' and MemoryAccessLoadAsync = '1') or BranchInstructionLinkAsync = '1' or LUIFlagAsync = '1' else '0';

	-- 
	WritebackRegAsync <= RD when RTypeFlagAsync = '1' or (OPCODE = "000000" and RT = "00000" and SHAMT = "00000" and FUNCT = "001001") else  -- R type or JRAL
						 RT when ArithmeticImmediateFlagAsync = '1' or (MemoryAccessFlagAsync = '1' and MemoryAccessLoadAsync = '1') or LUIFlagAsync = '1' else  -- I type & LW/H/B
						 "11111";  -- $RA for JAL


	--Data1Async <= --InputInterface.IncrementedPC when JumpFromImmediateAsync = '1' else  --or BranchInstructionFlagAsync = '1' else  -- J or JAL instructions
				  --RegData1Async;

	--Data2Async <= InputInterface.IncrementedPC(31 downto 28) & BASE & "00" when JumpFromImmediateAsync = '1' else  -- J or JAL instructions
	--Data2Async <= RegData2Async;  -- when RTypeFlagAsync = '1' or ShifterFlagAsync = '1';  
				  --resize(signed(InputInterface.IMM), 32) when ArithmeticExtendFlagAsync = '1' else
				  --resize(unsigned(InputInterface.IMM), 32);


	-- Controls Stall/Flush of pipeline stages
	PipelineManager: block is
		--signal ReadAfterLoadFlag: std_logic;
	begin

		process(Clock, Reset) begin

			if Reset = '1' then

				PipelineStall <= (others => '0');
				PipelineFlush <= (others => '0');

				--ReadAfterLoadFlag <= '0';

			--elsif rising_edge(Clock) then
			-- Writes flags @ clock falling edge so that stages can appropriately set their pipeline registers @ clock rising edge
			-- Inputs to Pipeline Manager are from pipeline registers, so there are no timing concerns with this approach 
			elsif falling_edge(Clock) then

				-- Default values
				PipelineStall <= (others => '0');
				PipelineFlush <= (others => '0');

				-- Check for wrongfull branch. "BranchOverride" comes from MEM/WB pipeline register
				if InputInterface.BranchOverride = '1' then
					--PipelineFlush <= "1110";
					PipelineFlush <= (3 => '0', others => '1');
				--end if;

				-- Check for Read after Load.
				elsif OutputInterface.MemoryAccessLoad = '1' and (RTypeFlagAsync = '1' or ArithmeticImmediateFlagAsync = '1') and (OutputInterface.WritebackReg = RS or OutputInterface.WritebackReg = RT) then
				    
					--PipelineStall <= "1000";
					PipelineStall <= (0 => '1', others => '0');
					--PipelineFlush <= "0100";
					PipelineFlush <= (1 => '1', others => '0');

				-- Check for unconditional jumps
				elsif JumpUnconditionalFlagAsync = '1' and not BranchDelaySlot then

					--PipelineFlush <= "1000";
					PipelineFlush <= (0 => '1', others => '0');

				end if;
				
				-- TODO: Stall if "jr" instruction is issued and jump register has not been written back yet

			end if;

		end process;

	end block PipelineManager;


	-- Pipeline Registers
	PipelineRegisters: process(Clock, Reset) begin

		if Reset = '1' then

			Except <= '0';

			-- To Execute stage
			OutputInterface.Data1 <= (others => '0');
			OutputInterface.Data2 <= (others => '0');
			OutputInterface.IMM <= (others => '0');
			OutputInterface.RS <= (others => '0');  -- To Forwarding Unit
			OutputInterface.RT <= (others => '0');  -- To Forwarding Unit
			--OutputInterface.IncrementedPC <= (others => '0');
			OutputInterface.BranchWasTaken <= '0';

			-- Execute stage control signals
			OutputInterface.ALUOP <= "000";
			OutputInterface.ArithmeticExtendFlag <= '0';
            OutputInterface.ArithmeticImmediateFlag <= '0';
            OutputInterface.ArithmeticUnsignedFlag <= '0';

			OutputInterface.BranchInstructionFlag <= '0';
			OutputInterface.BranchInstructionAroundZero <= '0';
			OutputInterface.ComparatorMasks <= (others => '0');
			OutputInterface.JumpFromImmediate <= '0';

			OutputInterface.SetFlag <= '0';
			OutputInterface.SetImmediate <= '0';
			OutputInterface.SetUnsigned <= '0';

			OutputInterface.ShifterFlag <= '0';
			OutputInterface.ShifterArithmetic <= '0';
			OutputInterface.ShifterLeft <= '0';
			OutputInterface.ShifterVariable <= '0';

			-- To Memory Access stage
			OutputInterface.MemoryAccessFlag <= '0';
			OutputInterface.MemoryAccessLoad <= '0';
			OutputInterface.MemoryAccessUnsigned <= '0';
			OutputInterface.MemoryAccessGranularity <= "00";

			-- To Writeback stage
			OutputInterface.LUIFlag <= '0';
			OutputInterface.WritebackReg <= (others => '0');
			OutputInterface.WritebackEnable <= '0';
			
		elsif rising_edge(Clock) then

			if Stall = '0' then

				-- Execute stage data
				--OutputInterface.Data1 <= Data1Async;
				OutputInterface.Data1 <= Data1;
				--OutputInterface.Data2 <= Data2Async;
				OutputInterface.Data2 <= Data2;
				OutputInterface.IMM <= IMM;
				OutputInterface.RS <= RS;  -- To Forwarding Unit
				OutputInterface.RT <= RT;  -- To Forwarding Unit
				--OutputInterface.IncrementedPC <= InputInterface.IncrementedPC;
				OutputInterface.BranchWasTaken <= BranchTakeFlag;

				-- Execute stage control signals
				OutputInterface.ALUOP <= ALUOPAsync;
				OutputInterface.ArithmeticExtendFlag <= ArithmeticExtendFlagAsync;
	            OutputInterface.ArithmeticImmediateFlag <= ArithmeticImmediateFlagAsync;
	            OutputInterface.ArithmeticUnsignedFlag <= ArithmeticUnsignedFlagAsync;
	            OutputInterface.LUIFlag <= LUIFlagAsync;

				OutputInterface.BranchInstructionFlag <= BranchInstructionFlagAsync;
				OutputInterface.BranchInstructionAroundZero <= BranchInstructionAroundZeroAsync;
				OutputInterface.ComparatorMasks <= ComparatorMasksAsync;
				OutputInterface.JumpFromImmediate <= JumpFromImmediateAsync;

				OutputInterface.SetFlag <= SetFlagAsync;
				OutputInterface.SetImmediate <= SetImmediateAsync;
				OutputInterface.SetUnsigned <= SetUnsignedAsync;

				OutputInterface.ShifterFlag <= ShifterFlagAsync;
				OutputInterface.ShifterArithmetic <= ShifterArithmeticAsync;
				OutputInterface.ShifterLeft <= ShifterLeftAsync;
				OutputInterface.ShifterVariable <= ShifterVariableAsync;

				-- Memory Access stage control signals
				if Flush = '1' then
					OutputInterface.MemoryAccessFlag <= '0';
				else
					OutputInterface.MemoryAccessFlag <= MemoryAccessFlagAsync;
				end if;
				OutputInterface.MemoryAccessLoad <= MemoryAccessLoadAsync;
				OutputInterface.MemoryAccessUnsigned <= MemoryAccessUnsignedAsync;
				OutputInterface.MemoryAccessGranularity <= MemoryAccessGranularityAsync;

				-- Writeback stage control signals
				OutputInterface.WritebackReg <= WritebackRegAsync;
				if Flush = '0' then
					OutputInterface.WritebackEnable <= WritebackEnableAsync;
				else
					OutputInterface.WritebackEnable <= '0';
				end if;

			end if;
			
		end if;

	end process PipelineRegisters;

	--assert not (WritebackRegAsync /= "00000" and WritebackEnableAsync = '1') report "Attempted write to $0" severity WARNING;
	
end architecture RTL;
