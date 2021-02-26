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
--             : v0.1 - Gewehr: Implements forwarding and branch predictor
--------------------------------------------------------------------------------
-- TODO        : Implement multiplication and division instructions
--               Implement SYSCALL and BREAK instructions
--               Implement branch decisions @ second stage
--------------------------------------------------------------------------------


library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.MIPS_PKG.all;


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
	
	-- Pipeline Stall and Flush controls (from Decode stage)
	signal PipelineStall: std_logic_vector(0 to 3);
	signal PipelineFlush: std_logic_vector(0 to 3);
	signal PipelineExcept: std_logic_vector(0 to 3);

begin

	-- Instruction memory interface
	FetchInput.InstructionMemoryDataOut <= InstructionMemoryDataOut;
	InstructionMemoryAddress <= FetchOutput.InstructionMemoryAddress;

	-- Data from Execute stage
	FetchInput.BranchAddress <= DecodeOutput.BranchAddress;
	FetchInput.BranchTakeFlag <= DecodeOutput.BranchTakeFlag;

	-- Instantiate Fetch stage
	FetchStage: entity work.FetchStage

		port map(
			
			Clock => Clock,
			Reset => Reset,
			
			Stall => PipelineStall(0),
			Flush => PipelineFlush(0),
			Except => PipelineExcept(0),

			InputInterface => FetchInput,
			OutputInterface => FetchOutput

		);

	-- Data from Fetch stage
	DecodeInput.Instruction <= FetchOutput.Instruction;
	DecodeInput.IncrementedPC <= FetchOutput.IncrementedPC;
	
	-- Branch control from Execute stage
    DecodeInput.BranchOverride <= ExecuteOutput.BranchOverride;
    DecodeInput.BranchStateEnable <= ExecuteOutput.BranchStateEnable;

	-- Data & control from Writeback stage
	DecodeInput.WritebackData <= WritebackOutput.WritebackData;
	DecodeInput.WritebackReg <= WritebackOutput.WritebackReg;
	DecodeInput.WritebackEnable <= WritebackOutput.WritebackEnable;

	-- Instantiate Decode stage
	DecodeStage: entity work.DecodeStage

		port map(
			
			Clock => Clock,
			Reset => Reset,
			
			Stall => PipelineStall(1),
			Flush => PipelineFlush(1),
			Except => PipelineExcept(1),
			
			PipelineStall => PipelineStall,
			PipelineFlush => PipelineFlush,

			InputInterface => DecodeInput,
			OutputInterface => DecodeOutput

		);


	-- Data from Decode stage
	ExecuteInput.Data1 <= DecodeOutput.Data1;
	ExecuteInput.Data2 <= DecodeOutput.Data2;
	ExecuteInput.RS <= DecodeOutput.RS;
	ExecuteInput.RT <= DecodeOutput.RT;
	ExecuteInput.IMM <= DecodeOutput.IMM;
	--ExecuteInput.IncrementedPC <= DecodeOutput.IncrementedPC;
	
	-- Data from Writeback stage (forwarding)
	ExecuteInput.WBStageData <= WritebackOutput.WritebackData;
	ExecuteInput.WBStageReg <= WritebackOutput.WritebackReg;
	ExecuteInput.WBStageEnable <= WritebackOutput.WritebackEnable;

	-- Control from Decode stage
	ExecuteInput.ALUOP <= DecodeOutput.ALUOP;
	ExecuteInput.ArithmeticExtendFlag <= DecodeOutput.ArithmeticExtendFlag;
	ExecuteInput.ArithmeticImmediateFlag <= DecodeOutput.ArithmeticImmediateFlag;
	ExecuteInput.ArithmeticUnsignedFlag <= DecodeOutput.ArithmeticUnsignedFlag;

	ExecuteInput.BranchInstructionFlag <= DecodeOutput.BranchInstructionFlag;
	ExecuteInput.BranchWasTaken <= DecodeOutput.BranchWasTaken;
	ExecuteInput.ComparatorMasks <= DecodeOutput.ComparatorMasks;
	ExecuteInput.BranchInstructionAroundZero <= DecodeOutput.BranchInstructionAroundZero;
	ExecuteInput.JumpFromImmediate <= DecodeOutput.JumpFromImmediate;

	ExecuteInput.SetFlag <= DecodeOutput.SetFlag;
	ExecuteInput.SetImmediate <= DecodeOutput.SetImmediate;
	ExecuteInput.SetUnsigned <= DecodeOutput.SetUnsigned;

	ExecuteInput.ShifterFlag <= DecodeOutput.ShifterFlag;
	ExecuteInput.ShifterArithmetic <= DecodeOutput.ShifterArithmetic;
	ExecuteInput.ShifterLeft <= DecodeOutput.ShifterLeft;
	ExecuteInput.ShifterVariable <= DecodeOutput.ShifterVariable;

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
			
			Stall => PipelineStall(2),
			Flush => PipelineFlush(2),
			Except => PipelineExcept(2),

			InputInterface => ExecuteInput,
			OutputInterface => ExecuteOutput

		);

	-- Data memory interface
	DataMemoryAddress <= MemoryAccessOutput.DataMemAddress;
	DataMemoryDataIn <= MemoryAccessOutput.DataMemDataIn;
	MemoryAccessInput.DataMemDataOut <= DataMemoryDataOut;
	DataMemoryWrite <= MemoryAccessOutput.DataMemWrite;
	
	-- Data from Execute stage
	MemoryAccessInput.ALUData <= ExecuteOutput.ALUResult;
	MemoryAccessInput.RegBankPassthrough <= ExecuteOutput.RegBankPassthrough;
	MemoryAccessInput.RT <= ExecuteOutput.RT;

	-- Control signals from Execute stage
	MemoryAccessInput.MemoryAccessFlag <= ExecuteOutput.MemoryAccessFlag;
	MemoryAccessInput.MemoryAccessLoad <= ExecuteOutput.MemoryAccessLoad;
	MemoryAccessInput.MemoryAccessUnsigned <= ExecuteOutput.MemoryAccessUnsigned;
	MemoryAccessInput.MemoryAccessGranularity <= ExecuteOutput.MemoryAccessGranularity;
	--MemoryAccessInput.LUIFlag <= ExecuteOutput.LUIFlag;
	
	MemoryAccessInput.WritebackEnable <= ExecuteOutput.WritebackEnable;
	MemoryAccessInput.WritebackReg <= ExecuteOutput.WritebackReg;

	-- Instantiate Memory Access stage
	MemoryAccessStage: entity work.MemoryAccessStage

		port map(
			
			Clock => Clock,
			Reset => Reset,
			
			Stall => PipelineStall(3),
			Flush => PipelineFlush(3),
			Except => PipelineExcept(3),

			InputInterface => MemoryAccessInput,
			OutputInterface => MemoryAccessOutput

		);


	-- Control signals from Execute stage
	WritebackInput.WritebackData <= MemoryAccessOutput.WritebackData;
	WritebackInput.WritebackEnable <= MemoryAccessOutput.WritebackEnable;
	WritebackInput.WritebackReg <= MemoryAccessOutput.WritebackReg;

	-- Instantiate Writeback stage
	WritebackStage: entity work.WritebackStage 

		port map(
			
			Clock => Clock,
			Reset => Reset,

			InputInterface => WritebackInput,
			OutputInterface => WritebackOutput

		);

	
end architecture Pipeline;
