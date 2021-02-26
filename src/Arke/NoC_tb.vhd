--------------------------------------------------------------------------------------
-- DESIGN UNIT  : NoC test bench                                                           --
-- DESCRIPTION  :                                                                   --
-- AUTHOR       : Everton Alceu Carara, Iaçanã Ianiski Weber & Michel Duarte        --
-- CREATED      : Aug 10th, 2015                                                    --
-- VERSION      : v1.0                                                             --
-- HISTORY      : Version 0.1 - Aug 10th, 2015                                      --
--              : Version 0.2.1 - Set 18th, 2015                                    --
--------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.Text_Package.all;
use work.Arke_pkg.all;

entity NoC_tb is
end NoC_tb;

architecture NoC_tb of NoC_tb is

    signal clk         : std_logic := '0';
    signal rst         : std_logic;
    signal data_in     : Array3D_data(0 to DIM_X-1, 0 to DIM_Y-1, 0 to DIM_Z-1);
    signal data_out    : Array3D_data(0 to DIM_X-1, 0 to DIM_Y-1, 0 to DIM_Z-1);
    signal control_in  : Array3D_control(0 to DIM_X-1, 0 to DIM_Y-1, 0 to DIM_Z-1);
    signal control_out : Array3D_control(0 to DIM_X-1, 0 to DIM_Y-1, 0 to DIM_Z-1);
    
    constant BasePath: string := "D:/Xilinx/Projects/Arke/";

begin
    
    clk <= not clk after 5 ns;
    
    rst <= '1', '0' after 3 ns;
    
    -- Router address format: router(x,y,z). For 2D-Mesh z = 0.
    -- IP connected at router(1,2,0)
    IP_12: entity work.DataManager
        generic map(
            fileNameIn => BasePath & "simulation/data/in/fileIn_12.txt",
            fileNameOut => BasePath & "simulation/data/out/fileOut_12.txt",
            clockCyclesDelay => 3,
            DataManagerPos => "12",
            Verbose => True
        )
        port map(
            clk         => clk,
            rst         => rst,
            data_in     => data_out(1,2,0),     -- (x,y,z)
            control_in  => control_out(1,2,0),  
            data_out    => data_in(1,2,0),
            control_out => control_in(1,2,0)
        );
    
    -- Router address format: router(x,y,z). For 2D-Mesh z = 0.
    -- IP connected at router(3,3,0)
    IP_33: entity work.DataManager
        generic map(
            fileNameIn => BasePath & "simulation/data/in/fileIn_33.txt",
            fileNameOut => BasePath & "simulation/data/out/fileOut_33.txt",
            clockCyclesDelay => 3,
            DataManagerPos => "33",
            Verbose => True
        )
        port map(
            clk         => clk,
            rst         => rst,
            data_in     => data_out(3,3,0),     -- (x,y,z)
            control_in  => control_out(3,3,0),  
            data_out    => data_in(3,3,0),
            control_out => control_in(3,3,0)
        );
    

    ARKE: entity work.NoC
    port map(
        clk         => clk,
        rst         => rst,
        data_in     => data_in,
        data_out    => data_out,
        control_in  => control_in,
        control_out => control_out
    );
    
end NoC_tb;
