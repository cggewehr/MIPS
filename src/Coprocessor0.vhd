--------------------------------------------------------------------------------
-- Title       : Coprocessor0
-- Project     : 5-stage pipeline MIPS implementation
--------------------------------------------------------------------------------
-- File        : Coprocessor0.vhd
-- Author      : Carlos Gewehr (carlos.gewehr@ecomp.ufsm.br)
-- Company     : UFSM, GMICRO (Grupo de Microeletronica)
-- Standard    : VHDL-1993
--------------------------------------------------------------------------------
-- Description : Partially implements MIPS coprocessor 0
--               Functionality is taken from "www.it.uu.se/education/course/homepage/os/vt18/module-1/mips-coprocessor-0/"
--               Implemented Registers:
--               $9: Count - Contains timer time step
--               $11: Compare - Contains timer target value	
--               $12: Status - Contains Interrupt Mask (15 downto 8), User Mode (4), Exception Level (1) and Interrupt Enable (0)
--               $13: Cause - Contains Pending Interrupts (15 downto 8) and Exception Code (6 downto 2)
--               $14: EPC - Contains address of exception-causing instruction
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


entity Coprocessor0 is

	port(
		
		Clock: in std_logic;
		Reset: in std_logic;

		CoprocessorInput: in Coprocessor0Input;
		CoprocessorOutput: in Coprocessor0Output

	);
	
end entity Coprocessor0;


architecture RTL of Coprocessor0 is

	--type RegisterBank_t is array(0 to 31) of std_logic_vector(31 downto 0);
	--signal RegisterBank: RegisterBank_t;
	signal RegCode: unsigned(4 downto 0);

	-- $9 (Count)
	signal Count: std_logic_vector(31 downto 0);

	-- $11 (Compare)
	signal Compare: std_logic_vector(31 downto 0);

	-- $12 (Status)
	signal InterruptMask: std_logic_vector(7 downto 0);
	signal UserMode: std_logic;
	signal ExceptionLevel: std_logic;
	signal InterruptEnable: std_logic;

	-- $13 (Cause)
	signal PendingInterrupts: std_logic_vector(7 downto 0);
	signal ExceptionCode: std_logic_vector(4 downto 0);

	-- $14 (Exception Program Counter)
	signal ExceptionProgramCounter: std_logic_vector(31 downto 0);

begin

	ReadRegCode <= unsigned(InputInterface.RegCode);

	-- Asynchrounously reads from implicit Register Bank
	process(ReadRegCode) begin

		-- $9 (Count)
		if ReadRegCode = 9 then
			OutputInterface.RegData <= Count;

		-- $11 (Compare)
		elsif ReadRegCode = 11 then
			OutputInterface.RegData <= Compare;

		-- $12 (Status)
		elsif ReadRegCode = 12 then
			OutputInterface.RegData <= x"0000" & InterruptMask & "000" & UserMode & "00" & ExceptionLevel & InterruptEnable;

		-- $13 (Cause)
		elsif ReadRegCode = 13 then
			OutputInterface.RegData <= x"0000" & PendingInterrupts & "00" & ExceptionCode & "000";

		-- $14 (Exception Program Counter)
		elsif ReadRegCode = 14 then
			OutputInterface.RegData <= ExceptionProgramCounter;

		else
			OutputInterface.RegData <= (others => '0');

		end if;

	end process;

	WriteRegCode <= unsigned(InputInterface.WriteRegCode);

	-- Writes to implicit Register Bank from main processor
	process(Clock, Reset) begin

		if Reset = '1' then

			-- $9 (Count)
			Count <= (others => '0');

			-- $11 (Compare)
			Compare <= (others => '0');

			-- $12 (Status)
			InterruptMask <= (others => '0');
			UserMode <= '0';
			ExceptionLevel <= '0';
			InterruptEnable <= '0';

			-- $13 (Cause)
			PendingInterrupts <= (others => '0');
			ExceptionCode <= (others => '0');

			-- $14 (Exception Program Counter)
			ExceptionProgramCounter <= (others => '0');

		--elsif rising_edge(Clock) then
		elsif falling_edge(Clock) then  -- Write @ falling edge to allow for sources other than InputInterface.RegData to write to registers @ rising edge

			-- $9 (Count)
			if WriteRegCode = 9 then
				Count <= InputInterface.RegData;

			-- $11 (Compare)
			elsif WriteRegCode = 11 then
				Compare <= InputInterface.RegData;

			-- $12 (Status)
			elsif WriteRegCode = 12 then
				--OutputInterface.RegData <= x"0000" & InterruptMask & "000" & UserMode & "000" & InterruptEnable;
				InterruptMask <= InputInterface.RegData(15 downto 8);
				UserMode <= InputInterface.RegData(4);
				ExceptionLevel <= InputInterface.RegData(1);
				InterruptEnable <= InputInterface.RegData(0);

			-- $13 (Cause)
			elsif WriteRegCode = 13 then
				--OutputInterface.RegData <= x"0000" & PendingInterrupts & "00" & ExceptionCode & "000";
				PendingInterrupts <= InputInterface.RegData(15 downto 8);
				ExceptionCode <= InputInterface.RegData(6 downto 2);

			-- $14 (Exception Program Counter)
			elsif WriteRegCode = 14 then
				OutputInterface.RegData <= ExceptionProgramCounter;

			end if;

		end if;

	end process; 


	-- Write to implicit register bank from specific functionality
	process(Clock) begin
	
		if rising_edge(Clock) then

			-- $12.4 (Status.UserMode)
			if InputInterface.UserModeWrite = '1' then
				UserMode <= InputInterface.UserModeData;
			end if;

			-- $12.1 (Status.ExceptionLevel)
			if InputInterface.ExceptionLevelWrite = '1' then
				ExceptionLevel <= InputInterface.ExceptionLevelData;
			end if;

			-- $12.0 (Status.InterruptEnable)
			if InputInterface.InterruptEnableWrite = '1' then
				InterruptEnable <= InputInterface.InterruptEnableData;
			end if;

			-- $13(14, 8) (Cause.PendingInterrupts)
			PendingInterrupts(6 downto 0) <= InputInterface.PendingInterrupts;
			--PendingInterrupts <= InterruptsMasked;

			-- $13.(6,2) (Cause.ExceptionCode)
			if InputInterface.ExceptionCodeWrite = '1' then
				ExceptionCode <= ExceptionCodeData;
			end if;							

			-- $14 (EPC)
			if InputInterface.EPCWrite = '1' then
				ExceptionProgramCounter <= InputInterface.EPCData;
			end if;			

		end if;

	end process;


	-- Counter (Hardwired to interrupt 7)
	Timer: block is 

		signal Counter: unsigned(31 downto 0);

	begin

		process(Clock, Reset) begin

			if Reset = '1' then

				Counter <= 0;

			elsif rising_edge(Clock) then

				Counter <= Counter + unsigned(Count);

				if Counter >= Compare then

					Counter <= '0';
					PendingInterrupts(7) <= '1';

				end if;

			end if;

		end process;
	
	end block Timer;

	
end architecture RTL;
