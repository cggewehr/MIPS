--------------------------------------------------------------------------------
-- Title       : MIPS_TB
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : MIPS_TB.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Testbench for MIPS processor + instruction and data memories
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


entity MIPS_TB is
	
	generic(
		DataMemoryFileName: string := "UNUSED";
		InstructionMemoryFileName: string := "UNUSED"
	);
	
end entity MIPS_TB;


architecture TB of MIPS_TB is

	signal Clock: std_logic := '0';
	constant ClockPeriod: time := 10 ns; 

	signal Reset: std_logic := '1';

	signal InstructionMemoryAddress, InstructionMemoryDataOut: std_logic_vector(31 downto 0);

	signal DataMemoryAddress, DataMemoryDataIn, DataMemoryDataOut: std_logic_vector(31 downto 0);
	signal DataMemoryWrite: std_logic;

	constant MARS_INSTRUCTION_OFFSET    : std_logic_vector(31 downto 0) := x"00400000";
    constant MARS_DATA_OFFSET           : std_logic_vector(31 downto 0) := x"10010000";

begin

	-- Generates 100 MHz clock
	ClockProc: process begin

		Clock <= not Clock;
		wait for ClockPeriod/2;

	end process;
	
	ResetProc: process begin
	
	   Reset <= '1';
	   wait for 105 ns;
	   Reset <= '0';
	   wait;
	
	end process ResetProc;
	

	-- Instantiates processor
	DUV: entity work.MIPS

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InstructionMemoryAddress => InstructionMemoryAddress,
			InstructionMemoryDataOut => InstructionMemoryDataOut,

			DataMemoryAddress => DataMemoryAddress,
			DataMemoryDataIn => DataMemoryDataIn,
			DataMemoryDataOut => DataMemoryDataOut,
			DataMemoryWrite => DataMemoryWrite

		);


	-- Instantiates instruction memory
	InstructionMemory: entity work.Memory

		generic map(

	        SIZE => 64,
	        START_ADDRESS => MARS_INSTRUCTION_OFFSET,
	        imageFileName => InstructionMemoryFileName

	    )

	    port map(  

	        Clock => Clock,

	        Address => InstructionMemoryAddress,
	        
	        Data_i => (others => '0'),
	        Data_o => InstructionMemoryDataOut,
	        MemWrite => '0'

	    );

	-- Instantiates data memory
	DataMemory: entity work.Memory

		generic map(

	        SIZE => 64,
	        START_ADDRESS => MARS_DATA_OFFSET,
	        imageFileName => DataMemoryFileName

	    )

	    port map(  

	        Clock => Clock,

	        Address => DataMemoryAddress,
	        
	        Data_i => DataMemoryDataIn,
	        Data_o => DataMemoryDataOut,
	        MemWrite => DataMemoryWrite

	    );
	
end architecture TB;
