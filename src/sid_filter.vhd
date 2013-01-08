--############################################################################
--State Variable Filter (Chamberlin version)
--
--References : Hal Chamberlin, "Musical Applications of Microprocessors,"
--             2nd Ed, Hayden Book Company 1985. pp 490-492.
--Code :
--//Input/Output
--    I - input sample
--    L - lowpass output sample
--    B - bandpass output sample
--    H - highpass output sample
--    N - notch output sample
--    F1 - Frequency control parameter
--    Q1 - Q control parameter
--    D1 - delay associated with bandpass output
--    D2 - delay associated with low-pass output
--
--// parameters:
--    Q1 = 1/Q
--    // where Q1 goes from 2 to 0, ie Q goes from .5 to infinity
--
--    // simple frequency tuning with error towards nyquist
--    // Fc is the filter's center frequency, and Fs is the sampling rate
--    F1 = 2*pi*Fc/Fs (* 2^18 for scaling)
--
--    // ideal tuning:
--    F1 = 2 * sin( pi * Fc / Fs )
--
--// algorithm
--    // loop
--    L = D2 + F1 * D1
--    H = I - L - Q1*D1
--    B = F1 * H + D1
--    N = H + L
--
--    // store delays
--    D1 = B
--    D2 = L
--
--    // outputs
--    L,H,B,N
--############################################################################

library ieee;
	use ieee.numeric_std.all;
	use ieee.std_logic_1164.all;
	--use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;

entity sid_filter is
	port (
		clk					: in  std_logic;								-- fast system clock
		f_start				: in  std_logic;								-- filter init (at Fsample rate)
		voice_1				: in  std_logic_vector(11 downto 0);	-- SID voice 1
		voice_2				: in  std_logic_vector(11 downto 0);	-- SID voice 2
		voice_3				: in  std_logic_vector(11 downto 0);	-- SID voice 3
		Filter_Fc_lo		: in  std_logic_vector( 7 downto 0);	-- SID register 15 =    -    -    -    -     -   FC2   FC1   FC0
		Filter_Fc_hi		: in  std_logic_vector( 7 downto 0);	-- SID register 16 = FC10  FC9  FC8  FC7   FC6   FC5   FC4   FC3
		Filter_Res_Filt	: in  std_logic_vector( 7 downto 0);	-- SID register 17 = RES3 RES2 RES1 RES0 FILTX FILT3 FILT2 FILT1
		Filter_Mode_Vol	: in  std_logic_vector( 7 downto 0);	-- SID register 18 = 3OFF   HP   BP   LP  VOL3  VOL2  VOL1  VOL0
		Filter_Out			: out std_logic_vector(17 downto 0)		-- Filter output

	);
end sid_filter;

architecture Behavioral of sid_filter is
	-- internal filter voice multiplex
	signal v1_in			: std_logic_vector(17 downto 0) := (others => '0');
	signal v2_in			: std_logic_vector(17 downto 0) := (others => '0');
	signal v3_in			: std_logic_vector(17 downto 0) := (others => '0');
	signal v1_out			: std_logic_vector(17 downto 0) := (others => '0');
	signal v2_out			: std_logic_vector(17 downto 0) := (others => '0');
	signal v3_out			: std_logic_vector(17 downto 0) := (others => '0');
	signal voice_mixed	: std_logic_vector(17 downto 0) := (others => '0');

	-- filter in/out
	signal Filter_In		: signed(17 downto 0) := (others => '0'); -- Filter Input
	signal FilterOutHP	: signed(17 downto 0) := (others => '0'); -- Filter High Pass Output
	signal FilterOutLP	: signed(17 downto 0) := (others => '0'); -- Filter Low  Pass Output
	signal FilterOutBP	: signed(17 downto 0) := (others => '0'); -- Filter Band Pass Output

	-- multiplier
	signal mA				: signed(17 downto 0) := (others => '0');
	signal mB				: signed(17 downto 0) := (others => '0');
	signal mP				: signed(35 downto 0) := (others => '0');

	-- internal filter feedback and control
	signal state			: std_logic_vector(1 downto 0) := (others => '0');
	signal z0				: signed(35 downto 0) := (others => '0'); -- high pass
	signal z1				: signed(35 downto 0) := (others => '0'); -- delay band pass
	signal z2				: signed(35 downto 0) := (others => '0'); -- delay low pass
	signal Filter_Fc		: signed(17 downto 0) := (others => '0');

	constant DC_offset	: std_logic_vector(17 downto 0)	:= "000000111111111111";
	constant q				: signed(17 downto 0)	:= "011111111111111111"; -- Q = 1.000, 1/Q = 0.999

begin
	Filter_Out	<= (voice_mixed(17 downto 0) * Filter_Mode_Vol(3 downto 0));

	-- voice in/out selectors
	v1_in		<= "000000" & voice_1 when Filter_Res_Filt(0) = '1' else (others => '0'); -- FILT1
	v2_in		<= "000000" & voice_2 when Filter_Res_Filt(1) = '1' else (others => '0'); -- FILT2
	v3_in		<= "000000" & voice_3 when Filter_Res_Filt(2) = '1' else (others => '0'); -- FILT3

	v1_out	<= "000000" & voice_1 when Filter_Res_Filt(0) = '0' else (others => '0'); -- FILT1
	v2_out	<= "000000" & voice_2 when Filter_Res_Filt(1) = '0' else (others => '0'); -- FILT2
	v3_out	<= "000000" & voice_3 when Filter_Res_Filt(2) = '0' else (others => '0'); -- FILT3

	FilterOutLP <= z2(35 downto 18) when Filter_Mode_Vol(4) = '1' else (others => '0');
	FilterOutBP <= z1(35 downto 18) when Filter_Mode_Vol(5) = '1' else (others => '0');
	FilterOutHP <= z0(35 downto 18) when Filter_Mode_Vol(6) = '1' else (others => '0');

	mP <= mA * mB; -- this multiplier is shared by all stages of the state machine below

	process
	begin
		wait until rising_edge(clk);
		if ( f_start = '1' ) then
			state <= "00";
			Filter_In <= signed( v1_in + (v2_in + v3_in ) );
			Filter_Fc <= signed("0000000" & Filter_Fc_hi & Filter_Fc_lo(2 downto 0)); -- raw register, needs to be scaled to Fc somehow

			voice_mixed <= (DC_offset) +
			(
				std_logic_vector(
					(
						(FilterOutLP) +
						(FilterOutBP)
					) +
						(FilterOutHP)
				)
			) +
			(
				(
					(v3_out) +
					(v2_out)
				) + (
					(v1_out)
				)
			);
		else
			case ( state ) is
				when "00" => state <= state + 1;
					mA <= q;
					mB <= z1(35 downto 18);
				when "01" => state <= state + 1;
					mA <= Filter_Fc;
					mB <= Filter_In - (mP(35 downto 18) + z2(35 downto 18));
				when "10" => state <= state + 1;
					mA <= Filter_Fc;
					mB <= z1(35 downto 18);
					z0 <= mB&"000000000000000000";
					z1 <= mP + z1;
				when "11" => state <= state + 1;
					z2 <= mP + z2;
				when others =>
					null;
			end case;
		end if;
	end process;

end Behavioral;
