
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.Arke_PKG;


entity NetworkInterface is

	generic(
		InputBufferSize: integer;
		OutputBufferSize: integer
	);

	port(
		
		Reset: in std_logic;

		-- MIPS interface
		MIPSClock: in std_logic;
		MIPSDataIn: in std_logic_vector(Arke_PKG.DATA_WIDTH - 1 downto 0);
		MIPSDataOut: out std_logic_vector(Arke_PKG.DATA_WIDTH - 1 downto 0);
		DataAV: in std_logic;
		Write: in std_logic;
		AccessBuffer: in std_logic;
		ArkeControlOut: inout std_logic_vector(Arke_PKG.CONTROL_WIDTH - 1 downto 0);

		-- NoC interface
		ArkeClock: in std_logic;
		ArkeDataIn: in std_logic_vector(Arke_PKG.DATA_WIDTH - 1 downto 0);
		ArkeDataOut: out std_logic_vector(Arke_PKG.DATA_WIDTH - 1 downto 0);
		ArkeControlIn: inout std_logic_vector(Arke_PKG.CONTROL_WIDTH - 1 downto 0)
		
	);
	
end entity NetworkInterface;


architecture RTL of NetworkInterface is

	-- Input buffer signals
	type rxState_t is (Sstandby, Sfill);
	signal rxState: rxState_t;
	signal inputbufferDataOut: std_logic_vector(31 downto 0);
	signal InputBufferEnable: std_logic;
	signal InputBufferReadConfirm: std_logic;
	signal InputBufferReadyFlag: std_logic;
	signal InputBufferAvailableFlag: std_logic;
	signal InputBufferLastElementFlag: std_logic;

	-- Output buffer signals
	type txState_t is (Sstandby, Stransmit);
	signal txState: txState_t;
	signal OutputBufferEnable: std_logic;
	signal OutputBufferReadyFlag: std_logic;
	signal OutputBufferAvailableFlag: std_logic;
	signal OutputBufferLastElementFlag: std_logic;

	-- Status register
	signal statusRegister: std_logic_vector(15 downto 0);
	signal statusRegisterAsync: std_logic_vector(15 downto 0);

	shared variable txGoAhead: std_logic;
	signal pendingEOP: std_logic;
	signal pendingEOPAV: std_logic;

	-- Defines specific bits in the status register for each control signal 
	constant statusPendingEOP: integer := 0;
	constant statusTxGoAhead: integer := 1;
	constant statusInputBufferAVFlag: integer := 2;

begin

	-- FIFO storing messages received from NoC
	InputBuffer: entity work.CircularBuffer

		generic map(
			BufferSize => InputBufferSize,
			DataWidth => Arke_PKG.DATA_WIDTH
		)
		port map (
			
			Reset => Reset,

			-- Input interface (from NoC)
			ClockIn => ArkeClock,
			DataIn => ArkeDataIn,
			--DataInAV => inputBufferEnable,
			DataInAV => ArkeControlIn(Arke_PKG.Tx),
			WriteACK => open,

			-- Output interface (to MIPS)
			ClockOut => MIPSClock,
			DataOut => inputBufferDataOut,
			--ReadConfirm => ArkeControl(Arke_PKG.STALL_GO),
			ReadConfirm => inputBufferReadConfirm,
			ReadACK => open,

			-- Status flags
			BufferEmptyFlag => open,
			BufferFullFlag => open,
			BufferReadyFlag => inputBufferReadyFlag,
			BufferAvailableFlag => inputBufferAvailableFlag,
			BufferLastElementFlag => inputBufferLastElementFlag

		);


	-- Wait for message to be read by MIPS before another message can be written to buffer
	--ArkeControl(Arke_PKG.STALL_GO) <= inputBufferReadConfirm when statusRegister(PendingEOP) = '0' else '0';
	ArkeControlIn(Arke_PKG.STALL_GO) <= inputBufferReadConfirm when rxState = Sfill else '0';


	-- Controls writing to input buffer
	InputFSM: process(ArkeClock, Reset) begin

		if Reset = '1' then

			rxState <= Sstandby;

			pendingEOP <= '0';
			pendingEOPAV <= '0';

		elsif rising_edge(ArkeClock) then

			case rxState is

				-- Wait for new flit
				when Sstandby =>

					-- Allows writing of new flit if no other full message is in input FIFO
					if ArkeControlIn(Arke_PKG.Tx) = '1' and inputBufferReadyFlag = '1' and statusRegister(statusPendingEOP) = '0' then
						rxState <= Sfill;
					end if;
					
				-- Wait for EOP flit
				when Sfill =>

					-- Sets PendingEOP flag in status register, to be cleared by MIPS after whole messages is read
					if ArkeControlIn(Arke_PKG.Tx) = '1' and ArkeControlIn(Arke_PKG.EOP) = '1' and inputBufferReadyFlag = '1' then
						--statusRegisterAsync(PendingEOP) <= '1';
						pendingEOP <= '1';
						pendingEOPAV <= '1';
					end if;

					-- Wait for flag to be set so state can safely be changed (Needed because status register is written to w.r.t. MIPSClock)
					if statusRegister(statusPendingEOP) = '1' then
						pendingEOPAV <= '0';
						rxState <= Sstandby;
					end if;
					
			end case;

		end if;

	end process InputFSM;


	-- FIFO storing messages to NoC
	OutputBuffer: entity work.CircularBuffer

		generic map(
			BufferSize => OutputBufferSize,
			DataWidth => Arke_PKG.DATA_WIDTH
		)
		port map (
			
			Reset => Reset,

			-- Input interface (from MIPS)
			ClockIn => MIPSClock,
			DataIn => MIPSDataIn(Arke_PKG.DATA_WIDTH - 1 downto 0),
			DataInAV => outputBufferEnable,
			WriteACK => open,

			-- Output interface (to NoC)
			ClockOut => ArkeClock,
			DataOut => ArkeDataOut,
			ReadConfirm => ArkeControlOut(Arke_PKG.STALL_GO),
			ReadACK => open,

			-- Status flags
			BufferEmptyFlag => open,
			BufferFullFlag => open,
			BufferReadyFlag => outputBufferReadyFlag,
			BufferAvailableFlag => outputBufferAvailableFlag,
			BufferLastElementFlag => outputBufferLastElementFlag

		);


	-- Output buffer control signals
	outputBufferEnable <= Write and AccessBuffer;
	ArkeControlOut(Arke_PKG.Tx) <= inputBufferAvailableFlag when txState = Stransmit else '0';
	ArkeControlOut(Arke_PKG.EOP) <= inputBufferLastElementFlag when txState = Stransmit else '0';


	-- Controls writing to output buffer
	OutputFSM: process(ArkeCLock, Reset) begin

		if Reset = '1' then

			txState <= Sstandby;

		elsif rising_edge(ArkeClock) then

			case txState is

				when Sstandby =>

					-- Control signal set by MIPS after message to be transmitted is in input buffer
					if statusRegister(statusTxGoAhead) = '1' then
						txState <= Stransmit;
					else
						txState <= Sstandby;
					end if;
					
				when Stransmit =>

					if ArkeControlOut(Arke_PKG.STALL_GO) = '1' and outputBufferLastElementFlag = '1' then 
						txGoAhead := '0';
						txState <= Sstandby;
					else
						txState <= Stransmit;
					end if;

			end case;

		end if;

	end process OutputFSM;


	-- Defines bits in the status register
	statusRegisterAsync(statusTxGoAhead) <= txGoAhead;
	statusRegisterAsync(statusPendingEOP) <= pendingEOP when pendingEOPAV = '1' else '0';
	statusRegisterAsync(statusInputBufferAVFlag) <= inputBufferAvailableFlag;
	statusRegisterAsync(15 downto 3) <= (others => '0');

	-- Controls writing to status register (from MIPS or from computed flags)
	StatusRegisterProc: process(MIPSClock, Reset) begin

		if Reset = '1' then
			statusRegister <= (others => '0');

		elsif rising_edge(MIPSClock) then

			if Write = '1' and AccessBuffer = '0' then

				-- statusRegister <= MIPSDataIn(31 downto 16) and MIPSDataIn(15 downto 0);
				for i in 0 to 15 loop 

					-- Controls writing of control signals according to mask in upper 16 bits
					if MIPSDataIn(i + 16) = '1' then
						statusRegister(i) <= MIPSDataIn(i);
					else
						statusRegister(i) <= statusRegisterAsync(i);
					end if;

				end loop;
				
			else
				statusRegister <= statusRegisterAsync;
			end if;

		end if;

	end process StatusRegisterProc;


	DataOutMux: MIPSDataOut <= inputBufferDataOut when AccessBuffer = '1' else ("0000" & statusRegister); 
	
end architecture RTL;
