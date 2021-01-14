--------------------------------------------------------------------------------
-- Title       : MemoryAccessStage
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : MemoryAccessStage.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Implements Memory Access stage in the 5 stage pipeline
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Gewehr: Initial implementation
--------------------------------------------------------------------------------
-- TODO        : Mask off bits for SB and SH instructions
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


entity MemoryAccessStage is

	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		InputInterface: in MemoryAccessInput;  -- Defined in MIPS_PKG
		OutputInterface: out MemoryAccessOutput  -- Defined in MIPS_PKG

	);
	
end entity MemoryAccessStage;


architecture RTL of MemoryAccessStage is

	signal , WritebackDataAsync: std_logic_vector(31 downto 0);

begin

	-- Sets data for synchronous write
	OutputInterface.DataMemWrite <= InputInterface.MemoryAccessFlag and (not InputInterface.MemoryAccessLoad);
	OutputInterface.DataMemDataIn <= InputInterface.RegBankPassthrough;  -- TODO: mask off bits for SB and SH

	-- Asynchronously reads from memory
	OutputInterface.DataMemAddress <= x"0000" & InputInterface.ALUData(15 downto 0) if InputInterface.MemoryAccessGranularity = "01" else
									  x"000000" & InputInterface.ALUData(7 downto 0) if InputInterface.MemoryAccessGranularity = "10" else
									  InputInterface.ALUData;
	
	-- Determines writeback data format  -- TODO: LUIFlag can be merged into MemoryAccessGranularity "11"
	DataFromMemMux <= InputInterface.DataMemDataOut(15 downto 0) & x"0000" when InputInterface.LUIFlag = '1' else
					  resize(unsigned(InputInterface.DataMemDataOut(15 downto 0)), 16) when InputInterface.MemoryAccessGranularity = "01" and InputInterface.MemoryAccessUnsigned = '1' else
					  resize(signed(InputInterface.DataMemDataOut(15 downto 0)), 16) when InputInterface.MemoryAccessGranularity = "01" and InputInterface.MemoryAccessUnsigned = '0' else
					  resize(unsigned(InputInterface.DataMemDataOut(7 downto 0)), 8) when InputInterface.MemoryAccessGranularity = "10" and InputInterface.MemoryAccessUnsigned = '1' else
					  resize(signed(InputInterface.DataMemDataOut(7 downto 0)), 8) when InputInterface.MemoryAccessGranularity = "10" and InputInterface.MemoryAccessUnsigned = '0' else
					  InputInterface.DataMemDataOut;  -- MemoryAccessGranularity = "00"

	WritebackDataAsync <=  DataFromMemMux when InputInterface.MemoryAccessFlag = '1' else
						   InputInterface.ALUData;


	-- Pipeline registers
	PipelineRegisters: process(Clock, Reset) begin

		if Reset = '1' then

			OutputInterface.WritebackData <= (others => '0');
			OutputInterface.WritebackEnable <= '0';
			OutputInterface.WritebackReg <= "00000";

		elsif rising_edge(Clock) then

			OutputInterface.WritebackData <= WritebackDataAsync;
			OutputInterface.WritebackEnable <= InputInterface.WritebackEnable;
			OutputInterface.WritebackReg <= InputInterface.WritebackReg;

		end if;

	end process PipelineRegisters;
	
end architecture RTL;
