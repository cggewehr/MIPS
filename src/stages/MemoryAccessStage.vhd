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
--               Implement LW -> SW forwarding
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


entity MemoryAccessStage is
	
	generic(
		EnableForwarding: boolean := True
	);
	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		Stall: in std_logic;
		Flush: in std_logic;
		Except: out std_logic;

		InputInterface: in MemoryAccessInput;  -- Defined in MIPS_PKG
		OutputInterface: inout MemoryAccessOutput  -- Defined in MIPS_PKG

	);
	
end entity MemoryAccessStage;


architecture RTL of MemoryAccessStage is

	signal DataFromMemMux, WritebackDataAsync: std_logic_vector(31 downto 0);

begin

	ForwardingUnit: if EnableForwarding generate

		OutputInterface.DataMemDataIn <= OutputInterface.WritebackData when (OutputInterface.WritebackReg = InputInterface.RT and OutputInterface.WritebackEnable = '1' and OutputInterface.WritebackReg /= "00000") else
										 InputInterface.RegBankPassthrough;

	end generate ForwardingUnit;

	--else -- ( "else" keyword in "if generate" construct only supported in VHDL-2008)
	NoForwardingUnit: if not EnableForwarding generate  -- VHDL-1993 compatible

		OutputInterface.DataMemDataIn <= InputInterface.RegBankPassthrough;

	--end generate ForwardingUnit;  -- ( "else" keyword in "if generate" construct only supported in VHDL-2008)
	end generate NoForwardingUnit;  -- VHDL-1993 compatible

	-- Sets data for synchronous write
	OutputInterface.DataMemWrite <= '0' when Flush = '1' else 
								    InputInterface.MemoryAccessFlag and (not InputInterface.MemoryAccessLoad);
	--OutputInterface.DataMemDataIn <= InputInterface.RegBankPassthrough;  -- TODO: mask off bits for SB and SH

	-- Asynchronously reads from memory
	--OutputInterface.DataMemAddress <= x"0000" & InputInterface.ALUData(15 downto 0) when InputInterface.MemoryAccessGranularity = "01" else
									  --x"000000" & InputInterface.ALUData(7 downto 0) when InputInterface.MemoryAccessGranularity = "10" else
									  --InputInterface.ALUData;
    OutputInterface.DataMemAddress <= InputInterface.ALUData;
	
	-- Determines writeback data format 
	--DataFromMemMux <= ((InputInterface.DataMemDataOut(15 downto 0)) & x"0000") when InputInterface.LUIFlag = '1' else
	DataFromMemMux <= std_logic_vector(resize(unsigned(InputInterface.DataMemDataOut(15 downto 0)), 32)) when InputInterface.MemoryAccessGranularity = "01" and InputInterface.MemoryAccessUnsigned = '1' else
					  std_logic_vector(resize(signed(InputInterface.DataMemDataOut(15 downto 0)), 32)) when InputInterface.MemoryAccessGranularity = "01" and InputInterface.MemoryAccessUnsigned = '0' else
					  std_logic_vector(resize(unsigned(InputInterface.DataMemDataOut(7 downto 0)), 32)) when InputInterface.MemoryAccessGranularity = "10" and InputInterface.MemoryAccessUnsigned = '1' else
					  std_logic_vector(resize(signed(InputInterface.DataMemDataOut(7 downto 0)), 32)) when InputInterface.MemoryAccessGranularity = "10" and InputInterface.MemoryAccessUnsigned = '0' else
					  InputInterface.DataMemDataOut;  -- MemoryAccessGranularity = "00"

	WritebackDataAsync <= DataFromMemMux when InputInterface.MemoryAccessFlag = '1' else
						  InputInterface.ALUData;


	-- Pipeline registers
	PipelineRegisters: process(Clock, Reset) begin

		if Reset = '1' then

			Except <= '0';

			OutputInterface.WritebackEnable <= '0';
			OutputInterface.WritebackReg <= "00000";
			OutputInterface.WritebackData <= (others => '0');
			
		elsif rising_edge(Clock) then

			if Stall = '0' then

				if Flush = '0' then
					OutputInterface.WritebackEnable <= InputInterface.WritebackEnable;
				else
					OutputInterface.WritebackEnable <= '0';
				end if;

				OutputInterface.WritebackReg <= InputInterface.WritebackReg;
				OutputInterface.WritebackData <= WritebackDataAsync;

			end if;
			
		end if;

	end process PipelineRegisters;
	
end architecture RTL;
