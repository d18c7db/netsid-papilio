--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:28:46 01/22/2012
-- Design Name:   
-- Module Name:   C:/Users/alex/workspace/NetSID-papilio/src/NetSID_top_tb.vhd
-- Project Name:  NetSID
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: NetSID
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use IEEE.std_logic_textio.all;

library std;
	use std.textio.all;

entity NetSID_top_tb is
	generic(stim_file: string :="stim.txt");
end NetSID_top_tb;
 
architecture behavior of NetSID_top_tb is 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    component NetSID
    port(
         ROT_CENTER : IN  std_logic;
         spi_sdo : IN  std_logic;
         RS232_DCE_TXD : IN  std_logic;
         RS232_DCE_RXD : OUT  std_logic;
         O_OUT : OUT  std_logic;
         spi_sck : OUT  std_logic;
         spi_sdi : OUT  std_logic;
         spi_dac_cs : OUT  std_logic;
         spi_rom_cs : OUT  std_logic;
         spi_amp_cs : OUT  std_logic;
         spi_adc_conv : OUT  std_logic;
         spi_amp_shdn : OUT  std_logic;
         spi_dac_clr : OUT  std_logic;
         strataflash_oe : OUT  std_logic;
         strataflash_ce : OUT  std_logic;
         strataflash_we : OUT  std_logic;
         platformflash_oe : OUT  std_logic;
         LED : OUT  std_logic_vector(7 downto 0);
         CLK_50MHZ : IN  std_logic
        );
    end component;
    

   --Inputs
   file stimulus: text open read_mode is stim_file;
   signal ROT_CENTER : std_logic := '0';
   signal spi_sdo : std_logic := '0';
   signal TXD : std_logic := '1';
   signal CLK_50MHZ : std_logic := '0';

 	--Outputs
   signal RXD : std_logic;
   signal O_OUT : std_logic;
   signal spi_sck : std_logic;
   signal spi_sdi : std_logic;
   signal spi_dac_cs : std_logic;
   signal spi_rom_cs : std_logic;
   signal spi_amp_cs : std_logic;
   signal spi_adc_conv : std_logic;
   signal spi_amp_shdn : std_logic;
   signal spi_dac_clr : std_logic;
   signal strataflash_oe : std_logic;
   signal strataflash_ce : std_logic;
   signal strataflash_we : std_logic;
   signal platformflash_oe : std_logic;
   signal LED : std_logic_vector(7 downto 0);

   signal baud_run : std_logic := '0';
	-- Clock period definitions
   constant CLK_50MHZ_period : time := 20 ns;
   constant baud_period  : time := 104.16666 us; -- 9600
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: NetSID PORT MAP (
          ROT_CENTER => ROT_CENTER,
          spi_sdo => spi_sdo,
          RS232_DCE_TXD => TXD,
          RS232_DCE_RXD => RXD,
          O_OUT => O_OUT,
          spi_sck => spi_sck,
          spi_sdi => spi_sdi,
          spi_dac_cs => spi_dac_cs,
          spi_rom_cs => spi_rom_cs,
          spi_amp_cs => spi_amp_cs,
          spi_adc_conv => spi_adc_conv,
          spi_amp_shdn => spi_amp_shdn,
          spi_dac_clr => spi_dac_clr,
          strataflash_oe => strataflash_oe,
          strataflash_ce => strataflash_ce,
          strataflash_we => strataflash_we,
          platformflash_oe => platformflash_oe,
          LED => LED,
          CLK_50MHZ => CLK_50MHZ
        );


   CLK_50MHZ_process :process
   begin
		wait for CLK_50MHZ_period/2;
		CLK_50MHZ <= not CLK_50MHZ;
   end process;
 
  serial_in : process
		variable inline : line;
		variable bv : std_logic_vector(7 downto 0);
	begin
		if baud_run = '1' then
			while not endfile(stimulus) loop
				readline(stimulus, inline);		-- read a line
				for byte in 0 to 3 loop				-- 4 bytes per line
					hread(inline, bv);					-- convert hex byte to vector
					TXD <= '0';				-- start bit
					wait for baud_period;
					for i in 0 to 7 loop				-- bits 0 to 7
						TXD <= bv(i);
						wait for baud_period;
					end loop;
					TXD <= '1';				-- stop bit
					wait for baud_period;
				end loop;
			end loop;
		else
			wait for baud_period;
		end if;
	end process;

	-- Stimulus process
	stim_proc: process
	begin		
		ROT_CENTER <= '1';
		baud_run <= '0';
		wait for CLK_50MHZ_period*5;
		ROT_CENTER <= '0';
		wait for CLK_50MHZ_period*10;
		baud_run <= '1';
		wait;
	end process;
END;
