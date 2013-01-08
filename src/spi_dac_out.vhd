library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity spi_dac_out is
	port (
		clk						: in  std_logic;
		reset					: in  std_logic;
		spi_sck				: out std_logic;
		spi_sdo				: out std_logic;
		spi_dac_cs		: out std_logic;
		ena_out				: out std_logic;
		data_in				: in std_logic_vector(11 downto 0)
	);
end spi_dac_out;

architecture Behavioral of spi_dac_out is
	signal half_clk		: std_logic := '0';
	signal ck_ena			: std_logic := '0';
	signal sdo				: std_logic := 'Z';
	signal dac_cs			: std_logic := '0';
	signal state			: std_logic_vector( 5 downto 0) := (others => '0');
	signal next_state	: std_logic_vector( 5 downto 0) := (others => '0');
	signal ser_reg		: std_logic_vector(23 downto 0) := (others => '0');

begin

--	// SPI_sck      = 0      Clock is Low (required)
--	// SPI_dac_cs   = 1      Deselect D/A
--	
--	// SPI clock is system clock/2
	process
	begin
		wait until rising_edge(clk);
		if (reset = '1') then
			half_clk <= '0';
		else
			half_clk <= not half_clk;
		end if;
	end process;

--
--	// synchronous counter sequences the spi bits
	process
	begin
		wait until rising_edge(clk);
		if (reset = '1') then
			state <= "000000";
		else
			if (half_clk = '1') then
				state <= next_state;
			end if;
		end if;
	end process;

--
--	// compute next state and spi outputs
	process(state)
	begin
--		defaults
		ck_ena <= '1';
		dac_cs <= '0';
		next_state <= state + 1;

		case state is
			when "000000" =>	-- 1st cycle: CS high
				ck_ena <= '0';
				dac_cs <= '1';

				when "011000" =>	-- 25th cycle: reset
					next_state <= (others => '0');
				when others => null;
		end case;
	end process;

--
--	// Data register
	process
	begin
		wait until rising_edge(clk);
		if (ck_ena = '1') then
			if (half_clk = '1') then
				ser_reg <= ser_reg(22 downto 0) & '0';
			end if;
		else
			ser_reg <= "00110000" & data_in & "0000";
		end if;
	end process;

--
--	// Output registers
	process
	begin
		wait until rising_edge(clk);
		spi_sck <= half_clk and ck_ena;
		spi_sdo <= ser_reg(23);
		spi_dac_cs <= dac_cs;
		ena_out <= (not half_clk) and (not ck_ena);
	end process;

end Behavioral;
