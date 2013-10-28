-------------------------------------------------------------------------------
--
-- This is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License,
-- or any later version, see <http://www.gnu.org/licenses/>
--
-- This is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- Company:  N/A
-- Engineer: Alex
--
-- Create Date:   00:09:21 07/25/2011
-- Design Name:   
-- Module Name:   C:/Users/alex/workspace/NetSID/build/NetSID_top.vhd
-- Project Name:  NetSID
-- Target Device: XC3S500E-VQ100-4
-- Tool versions: ISE 13.1
-- Description:   
-- 
-- NetSID top module
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- 
-------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

library UNISIM;
	use UNISIM.Vcomponents.all;

entity NetSID is
	port (
		I_RESET						: in  std_logic;	-- active low reset
		CLK_IN						: in  std_logic;	-- main clock 32Mhz
		O_AUDIO_L					: out std_logic;	-- PWM audio out
		O_AUDIO_R					: out std_logic;	-- PWM audio out
		LED							: out std_logic;	-- output LED
		USB_TXD						: in  std_logic;	-- RS232 data to FPGA
		USB_RXD						: out std_logic	-- RS232 data from FPGA
		);
	end;

architecture RTL of NetSID is

	--
	-- declaration of UART transmitter with integral 16 byte FIFO buffer
	--
	component uart_tx
	Port (
		data_in						: in  std_logic_vector(7 downto 0);
		write_buffer				: in  std_logic;
		reset_buffer				: in  std_logic;
		en_16_x_baud				: in  std_logic;
		serial_out					: out std_logic;
		buffer_full					: out std_logic;
		buffer_half_full			: out std_logic;
		clk							: in  std_logic);
	end component;

	--
	-- declaration of UART Receiver with integral 16 byte FIFO buffer
	--
	component uart_rx
	Port (
		serial_in					: in  std_logic;
		data_out						: out std_logic_vector(7 downto 0);
		read_buffer					: in  std_logic;
		reset_buffer				: in  std_logic;
		en_16_x_baud				: in  std_logic;
		buffer_data_present		: out std_logic;
		buffer_full					: out std_logic;
		buffer_half_full			: out std_logic;
		clk							: in  std_logic);
	end component;

	type uartsm is (
		st00,
		st01,
		st02,
		st03,
		st04
	);

	type RAMtoSIDState is (
		stInit,
		stDelay1,
		stDelay2,
		stSync,
		stWait1,
		stWait2,
		stAddr,
		stData,
		stWrite,
		stIdle
	);

	signal clk01					: std_logic := '0';	--  1 Mhz
	signal clk04					: std_logic := '0';	--  4 Mhz
	signal clk32					: std_logic := '0';	-- 32 Mhz

	signal stUARTnow				: uartsm := st01;
	signal stUARTnext				: uartsm := st01;
	signal tx_data					: std_logic_vector(7 downto 0) := (others => '1');
	signal rx_data					: std_logic_vector(7 downto 0) := (others => '1');
	signal tx_full					: std_logic := '0';
	signal write_to_uart			: std_logic := '0';
	signal rx_data_present		: std_logic := '0';
	signal en_16_x_baud			: std_logic := '0';

	signal stSIDnow				: RAMtoSIDState := stInit;
	signal stSIDnext				: RAMtoSIDState := stInit;
	signal sid_audio				: std_logic_vector(17 downto 0) := (others => '0');
	signal sid_addr				: std_logic_vector( 4 downto 0) := (others => '0');
	signal sid_din					: std_logic_vector( 7 downto 0) := (others => '0');
	signal sid_we					: std_logic := '0';

	signal ram_ai					: std_logic_vector(13 downto 0) := (others => '0');
	signal ram_ao					: std_logic_vector(13 downto 0) := (others => '1');
	signal ram_do					: std_logic_vector( 7 downto 0) := (others => '0');

	signal cycle_cnt				: std_logic_vector(20 downto 0) := (others => '0');
	signal nrst						: std_logic := '0';
	signal rst						: std_logic := '0';
	signal audio_pwm				: std_logic := '0';
	signal nrxdp					: std_logic := '0';
	signal fifo_empty				: std_logic := '1';
	signal buf_full				: std_logic := '0';
	signal buf_full_last			: std_logic := '0';
	signal buf_full_fe			: std_logic := '0';
	signal buf_full_re			: std_logic := '0';

begin
	O_AUDIO_L		<= audio_pwm;
	O_AUDIO_R		<= audio_pwm;
	nrst				<= I_RESET;
	nrxdp				<= not rx_data_present;
	en_16_x_baud 	<= '1';					-- held high when running at max speed as per manual

  -----------------------------------------------------------------------------
  -- Clocks
  -----------------------------------------------------------------------------
	--
	-- provides a selection of synchronous clocks 1, 4 and 32 Mhz
	-- could provide the baud clock for serial comms
	-- provides a timed reset signal
	--
	u_clocks : entity work.NetSID_CLOCKS
	port map (
		I_CLK			=> CLK_IN,
		I_RESET		=> nrst,
		--
		O_CLK_1M		=> clk01,
		O_CLK_4M		=> clk04,
		O_CLK_32M	=> clk32,
		O_RESET		=> rst				-- timed active high reset
	);

  -----------------------------------------------------------------------------
  -- UART RS232 rx and tx
  -----------------------------------------------------------------------------
  --
  -- 8-bit, 1 stop-bit, no parity transmit and receive macros.
  -- Each contains an embedded 16-byte FIFO buffer.
  --
	u_tx : uart_tx 
	port map (
		data_in						=> tx_data,
		write_buffer				=> write_to_uart,
		reset_buffer				=> rst,
		en_16_x_baud				=> en_16_x_baud,
		serial_out					=> USB_RXD,					-- to RX input of external device
		buffer_full					=> tx_full,
		buffer_half_full			=> open,
		clk							=> clk32
	);

	u_rx : uart_rx
	port map (
		data_out						=> rx_data,
		read_buffer					=> '1',
		reset_buffer				=> rst,
		en_16_x_baud				=> en_16_x_baud,
		serial_in					=> USB_TXD,					-- to TX output of external device
		buffer_data_present		=> rx_data_present,
		buffer_full					=> open,
		buffer_half_full			=> open,
		clk							=> clk32
	);

  -----------------------------------------------------------------------------
  -- FIFO buffer
  -----------------------------------------------------------------------------
	--
	-- dual ported async read / write access
	--
  u_ram : entity work.RAM_16K
	port map (
		DOA	=> ram_do,
		ADDRA	=> ram_ao,
		CLKA	=> clk32,
		--
		DIB	=> rx_data,
		ADDRB	=> ram_ai,
		CLKB	=> nrxdp
	);

	u_dac: entity work.dac
	port map(
		clk_i				=> clk32,
		reset				=> rst,
		dac_i				=> sid_audio(17 downto 8),
		dac_o				=> audio_pwm
	);

  -----------------------------------------------------------------------------
  -- SID 6581
  -----------------------------------------------------------------------------
	--
	-- Implementation of SID sound chip
	--
  u_sid6581 : entity work.sid6581
	port map (
		clk_1mhz			=> clk01,		-- main SID clock
		clk32				=> clk32,		-- main clock signal
		reset				=> rst,			-- active high reset signal
		cs					=> '1',			-- active high  chip select
		we					=> sid_we,		-- active high write enable
		addr				=> sid_addr,	-- address lines 5 bits
		di					=> sid_din,		-- data to chip, 8 bits
		do					=> open,			-- data from chip, 8 bits
		pot_x				=> x"00",		-- paddle input-X 8 bits
		pot_y				=> x"00",		-- paddle input-Y 8 bits
		audio_data		=> sid_audio	-- audio out 18 bits
	);

	-----------------------------------------------------------------------------
	-- state machine control for ram_to_sid process
	sm_control : process (clk32, rst)
	begin
		if falling_edge(clk32) then
			if rst = '1' then
				stSIDnow <= stInit;
			else
				stSIDnow <= stSIDnext;
			end if;
		end if;
	end process;

	-- detect FIFO empty state
	fifo_control : process(clk32)
	begin
		if falling_edge(clk32) then
			if (ram_ai = ram_ao) then
					fifo_empty <= '1';
				else
					fifo_empty <= '0';
			end if;
		end if;
	end process;

	-- copy data from FIFO to SID at cycle accurate rate
	-- read pointer cannot overtake write pointer and will block (wait)
	ram_to_sid : process (clk04, stSIDnow, rst)
	begin
		if rst = '1' then
			ram_ao <= (others => '1');
			stSIDnext	<= stInit;
		elsif rising_edge(clk04) then
			if fifo_empty = '0' then
				case stSIDnow is
					when stInit =>
						sid_we		<= '0';
						ram_ao		<= (others => '0');
						cycle_cnt	<= (others => '0');
						stSIDnext	<= stDelay1;
					when stDelay1 =>
						sid_we		<= '0';
						cycle_cnt(17 downto 10) <= ram_do;	-- delay high
						ram_ao		<= ram_ao + 1;
						stSIDnext	<= stDelay2;
					when stDelay2 =>
						cycle_cnt(9 downto 2)  <= ram_do;	-- delay low
						ram_ao		<= ram_ao + 1;
						stSIDnext	<= stAddr;
					when stAddr =>
						sid_addr		<= ram_do(4 downto 0);	-- address
						ram_ao		<= ram_ao + 1;
						stSIDnext	<= stData;
					when stData =>
						sid_din		<= ram_do;					-- value
						ram_ao		<= ram_ao + 1;
						stSIDnext	<= stSync;
					when stSync =>
						if cycle_cnt = x"0000" then
							stSIDnext <= stWrite;
						else
							cycle_cnt <= cycle_cnt - 1;		-- wait cycles x4 (since this runs at clk04)
							stSIDnext <= stSync;
						end if;
					when stWrite =>
						sid_we		<= '1';
						stSIDnext	<= stDelay1;
					when others		=> null;
				end case;
			end if;
		end if;
	end process;

	-----------------------------------------------------------------------------
	-- data is streaming in from serial at 2000000-8N1 as a byte quad "DD DD RR VV"
	-- DDDD is a big-endian delay in SID clock cycles (985248 Hz PAL or 1022727 Hz NTSC)
	-- RR is a SID register
	-- VV is the value to be written to that register
	--
	-- example: 00 08 04 ff 
	--					means: delay 0008 cycles then write ff to register 04

	-- this receives data from the serial port and buffers
	-- it into 16K of RAMB FIFO
	--
	uart_to_ram : process(clk32, rx_data_present, rst)
	begin
		if rst = '1' then
			ram_ai <= (others => '1');
		elsif rising_edge(rx_data_present) then
			ram_ai <= ram_ai + 1;
		end if;
	end process;

	-- debug test points
	LED <= buf_full;

	-----------------------------------------------------------------------------

	-- detect rising and falling edges of buf_full
	buf_full_fe <=     buf_full_last and not buf_full;
	buf_full_re <= not buf_full_last and     buf_full;

	detect_edges : process(clk32)
	begin
		if falling_edge(clk32) then
			buf_full_last <= buf_full;
		end if;
	end process;

	-- transmit a serial byte to stop or start incoming data flow
	uart_fifo_tx : process(clk32)
	begin
		if falling_edge(clk32) then
			if buf_full_re = '1' or buf_full_fe = '1' then
				stUARTnow <= st00;
			else
				stUARTnow <= stUARTnext;
			end if;
		end if;
	end process;

	-- strobe uart we line for exactly one clock cycle
	uart_fifo_we : process(clk32)
	begin
		if rising_edge(clk32) then
			case stUARTnow is
				when st00 =>
					write_to_uart <= '1';
					stUARTnext <= st01;
				when st01 =>
					write_to_uart <= '0';
					stUARTnext <= st01;
				when others		=> null;
			end case;
		end if;		
	end process;

	-- detect a buffer almost full condition
	fifo_handshake : process(clk32)
	begin
		if falling_edge(clk32) then
			if (ram_ai - ram_ao) > 12288 then
				tx_data <= x"45"; -- End TX
				buf_full <= '1';
			elsif (ram_ai - ram_ao) < 4096 then
				tx_data <= x"53"; -- Start TX
				buf_full <= '0';
			end if;
		end if;
	end process;

end RTL;
