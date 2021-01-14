--------------------------------------------------------------------------------
-- Title       : MIPS_TOP
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : MIPS_TOP.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Top level entity containing pipeline stages instantiation and 
--              interface connections
--------------------------------------------------------------------------------
-- Revisions   : v0.01 - Gewehr: Initial implementation (no MUL/DIV, no SYSCALL, no forwarding, branch decision @ third stage, no stall/flush controls)
--------------------------------------------------------------------------------
-- TODO        : Implement multiplication and division instructions
--               Implement SYSCALL and BREAK instructions
--               Implement Forwarding
--               Implement branch decisions @ second stage
--               Implement pipeline stall/flush
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use MIPS_PKG.all;


entity MIPS is

	port(
		
		Clock: in std_logic;
		Reset: in std_logic;

		InstructionMemoryAddress: out std_logic_vector(31 downto 0);
		InstructionMemoryDataOut: in std_logic_vector(31 downto 0);

		DataMemoryAddress: out std_logic_vector(31 downto 0);
		DataMemoryDataIn: out std_logic_vector(31 downto 0);
		DataMemoryDataOut: in std_logic_vector(31 downto 0);
		DataMemoryWrite: out std_logic

	);
	
end entity MIPS;


architecture Pipeline of MIPS is

	-- Fetch stage entity interfaces
	signal FetchInput: FetchInput;
	signal FetchOutput: FetchOutput;

	-- Decode stage entity interfaces
	signal DecodeInput: DecodeInput;
	signal DecodeOutput: DecodeOutput;

	-- Execute stage entity interfaces
	signal ExecuteInput: ExecuteInput;
	signal ExecuteOutput: ExecuteOutput;

	-- Memory Access stage entity interfaces
	signal MemoryAccessInput: MemoryAccessInput;
	signal MemoryAccessOutput: MemoryAccessOutput;

	-- Writeback stage entity interfaces
	signal WritebackInput: WritebackInput;
	signal WritebackOutput: WritebackOutput;

begin

	-- Instruction memory interface
	FetchInput.InstructionMemoryDataOut <= InstructionMemoryDataOut;
	InstructionMemoryAddress <= FetchOutput.InstructionMemoryAddress;

	-- Data from Execute stage
	FetchInput.BranchAddress <= ExecuteOutput.BranchAddress;
	FetchInput.BranchFlag <= ExecuteOutput.BranchTakeFlag;

	-- Instantiate Fetch stage
	FetchStage: entity work.FetchStage

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InputInterface => FetchInput,
			OutputInterface => FetchOutput

		);

	-- Data from Fetch stage
	DecodeInput.Instruction <= FetchOutput.Instruction;
	DecodeInput.IncrementedPC <= FetchOutput.IncrementedPC;

	-- Data & control from Writeback stage
	DecodeInput.WritebackData <= WritebackOutput.WritebackData;
	DecodeInput.WritebackReg <= WritebackOutput.WritebackReg;
	DecodeInput.WritebackEnable <= WritebackOutput.WritebackEnable;

	-- Instantiate Decode stage
	DecodeStage: entity work.DecodeStage

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InputInterface => DecodeInput,
			OutputInterface => DecodeOutput

		);


	-- Data from Decode stage
	ExecuteInput.Data1 <= DecodeOutput.Data1;
	ExecuteInput.Data2 <= DecodeOutput.Data2;
	ExecuteInput.IMM <= DecodeOutput.IMM;

	-- Control from Decode stage
	ExecuteInput.ALUOP <= DecodeOutput.ALUOP;

	ExecuteInput.BranchInstructionFlag <= DecodeOutput.BranchInstructionFlag;
	ExecuteInput.BranchInstructionModes <= DecodeOutput.BranchInstructionModes;
	ExecuteInput.BranchInstructionAroundZero <= DecodeOutput.BranchInstructionAroundZer;

	ExecuteInput.SetFlag <= DecodeOutput.SetFlag;
	ExecuteInput.SetImediate <= DecodeOutput.SetImediate;
	ExecuteInput.SetUnsigned <= DecodeOutput.SetUnsigned;

	ExecuteInput.ShifterFlag <= DecodeOutput.ShifterFlag;
	ExecuteInput.ShifterArithmetic <= DecodeOutput.ShifterArithmetic;
	ExecuteInput.ShifterLeft <= DecodeOutput.ShifterLeft;
	ExecuteInput.ShifterVariable <= DecodeOutput.ShifterLeft;

	-- Memory Access stage control signals
	ExecuteInput.LUIFlag <= DecodeOutput.LUIFlag;
	ExecuteInput.MemoryAccessFlag <= DecodeOutput.MemoryAccessFlag;
	ExecuteInput.MemoryAccessLoad <= DecodeOutput.MemoryAccessLoad;
	ExecuteInput.MemoryAccessUnsigned <= DecodeOutput.MemoryAccessUnsigned;
	ExecuteInput.MemoryAccessGranularity <= DecodeOutput.MemoryAccessGranularity;

	-- Writeback stage control signals
	ExecuteInput.WritebackReg <= DecodeOutput.WritebackReg;
	ExecuteInput.WritebackEnable <= DecodeOutput.WritebackEnable;

	-- Instantiate Execute stage
	ExecuteStage: entity work.ExecuteStage

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InputInterface => ExecuteInput,
			OutputInterface => ExecuteOutput

		);

	-- Data memory interface
	DataMemoryAddress <= MemoryAccessOutput.DataMemAddress;
	DataMemoryDataIn <= MemoryAccessOutput.DataMemDataIn;
	MemoryAccessInput.DataMemDataOut <= DataMemoryDataOut;
	DataMemoryWrite <= MemoryAccessOutput.DataMemWrite;

	-- Control signals from Execute stage
	MemoryAccessInput.WritebackEnable <= ExecuteOutput.WritebackEnable;
	MemoryAccessInput.WritebackReg <= ExecuteOutput.WritebackReg;

	-- Instantiate Memory Access stage
	MemoryAccessStage: entity MemoryAccessStage

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InputInterface => MemoryAccessInput,
			OutputInterface => MemoryAccessOutput

		);


	-- Control signals from Execute stage
	WritebackInput.WritebackData <= MemoryAccessOutput.WritebackData;
	WritebackInput.WritebackEnable <= MemoryAccessOutput.WritebackEnable;
	WritebackInput.WritebackReg <= MemoryAccessOutput.WritebackReg;

	-- Instantiate Writeback stage
	WritebackStage: entity WritebackStage 

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InputInterface => WritebackInput,
			OutputInterface => WritebackOutput

		);

	
end architecture Pipeline;
