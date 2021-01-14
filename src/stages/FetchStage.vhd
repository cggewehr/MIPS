--------------------------------------------------------------------------------
-- Title       : FetchStage
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : FetchStage.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Implements Fetch stage in the 5 stage pipeline
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Gewehr: Initial implementation
--------------------------------------------------------------------------------
-- TODO        : 
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


entity FetchStage is

	generic(
		PCStartAddress: std_logic_vector(31 downto 0) := x"00400000"
	);

	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		InputInterface: in FetchInput;  -- Defined in MIPS_PKG
		OutputInterface: out FetchOutput  -- Defined in MIPS_PKG

	);
	
end entity FetchStage;


architecture RTL of FetchStage is

	signal ProgramCounter: std_logic_vector(31 downto 0);
	signal IncrementedPCAsync: std_logic_vector(31 downto 0);

begin

	-- Maps PC to instruction memory address (memory is read asynchronously)
	OutputInterface.InstructionMemoryAddress <= ProgramCounter;

	-- Increments PC by 4
	PCAdder: IncrementedPCAsync <= unsigned(ProgramCounter) + to_unsigned(4, 32);

	-- Writes to PC register either the target jump address, if a branch is to be taken, or increments PC, if no branch is to be taken
	PCRegister: process(Clock, Reset) begin

		if Reset = '1' then
			ProgramCounter <= PCStartAddress;

		elsif rising_edge(Clock) then

			PCMux: if InputInterface.BranchTakeFlag = '1' then
				ProgramCounter <= InputInterface.BranchAddress;

			else
				ProgramCounter <= IncrementedPC;

			end if;

		end if;

	end process FetchStageProc;


	-- Pipeline Registers
	PipelineRegisters: process(Clock, Reset) begin

		if Reset = '1' then

			OutputInterface.Instruction <= (others => '0');
			OutputInterface.IncrementedPCAddress <= (others => '0');

		elsif rising_edge(Clock) then
			
			OutputInterface.Instruction <= InputInterface.InstructionMemoryDataOut;
			OutputInterface.IncrementedPC <= IncrementedPCAsync;

		end if;

	end process;

	-- TODO: Stop simulation after a HALT instruction is fetched
	--assert DecodeOPCODE(InputInterface.InstructionMemoryDataOut(31 downto 26)) /= "HALT" report "HALT instruction fetched, stopping simulation" severity FAILURE;

end architecture RTL;