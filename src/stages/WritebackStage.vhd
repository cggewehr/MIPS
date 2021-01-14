--------------------------------------------------------------------------------
-- Title       : WritebackStage
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : WritebackStage.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Implements Writeback stage in the 5 stage pipeline
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


entity WritebackStage is

	port(

		Clock: in std_logic;  -- From top level entity
		Reset: in std_logic;  -- From top level entity

		InputInterface: out WritebackInput;  -- Defined in MIPS_PKG
		OutputInterface: out WritebackOutput  -- Defined in MIPS_PKG

	);
	
end entity WritebackStage;


architecture RTL of WritebackStage is

begin

	OutputInterface.WritebackData <= InputInterface.WritebackData;
	OutputInterface.WritebackReg <= InputInterface.WritebackReg;
	OutputInterface.WritebackEnable <= InputInterface.WritebackEnable;
	
end architecture RTL;
