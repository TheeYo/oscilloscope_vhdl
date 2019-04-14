library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_oscilloscope is
end entity test_oscilloscope;

architecture test of test_oscilloscope is
	component DE1_oscilloscope port(
				/*      ADC      */
				ADC_CONVST:	out	std_logic;
				ADC_DIN:		out	std_logic;
				ADC_DOUT:	out	std_logic;
				ADC_SCLK:	out	std_logic;

				/*       CLOCK      */
				CLOCK2_50:	in		std_logic;
				CLOCK3_50:	in		std_logic;
				CLOCK4_50:	in		std_logic;
				CLOCK_50:	in		std_logic;

				/*       SEG7      */
				HEX0: out std_logic_vector(6 downto 0);
				HEX1: out std_logic_vector(6 downto 0);
				HEX2: out std_logic_vector(6 downto 0);
				HEX3: out std_logic_vector(6 downto 0);
				HEX4: out std_logic_vector(6 downto 0);
				HEX5: out std_logic_vector(6 downto 0);

				/*       KEY      */
				KEY: in std_logic_vector(3 downto 0);

				/*       LED      */
				LEDR: out std_logic_vector(9 downto 0);

				/*       SW      */
				SW: 	in std_logic_vector(9 downto 0);

				/*       VGA      */
				VGA_BLANK_N: out std_logic;
				VGA_B:	out std_logic_vector(7 downto 0);
				VGA_CLK:	out std_logic;
				VGA_G:	out std_logic_vector(7 downto 0);
				VGA_HS:	out std_logic;
				VGA_R:	out std_logic_vector(7 downto 0);
				VGA_SYNC_N:	out std_logic;
				VGA_VS:	out std_logic;

				/*       GPIO_0, GPIO_0 connect to GPIO Default      */
				GPIO_0: 	inout		std_logic_vector(35 downto 0);

				/*       GPIO_1, GPIO_1 connect to GPIO Default      */
				GPIO_1: 	inout		std_logic_vector(35 downto 0) );
	end component DE1_oscilloscope;


	signal ADC_CONVST:	std_logic;
	signal ADC_DIN:		std_logic;
	signal ADC_DOUT:	std_logic;
	signal ADC_SCLK:	std_logic;
	signal CLOCK2_50:	std_logic;
	signal CLOCK3_50:	std_logic;
	signal CLOCK4_50:	std_logic;
	signal CLOCK_50:	std_logic;
	signal HEX0: std_logic_vector(6 downto 0);
	signal HEX1: std_logic_vector(6 downto 0);
	signal HEX2: std_logic_vector(6 downto 0);
	signal HEX3: std_logic_vector(6 downto 0);
	signal HEX4: std_logic_vector(6 downto 0);
	signal HEX5: std_logic_vector(6 downto 0);
	signal KEY: std_logic_vector(3 downto 0);
	signal LEDR: std_logic_vector(9 downto 0);
	signal SW: 	std_logic_vector(9 downto 0);
	signal VGA_BLANK_N: std_logic;
	signal VGA_B:	std_logic_vector(7 downto 0);
	signal VGA_CLK:	std_logic;
	signal VGA_G:	std_logic_vector(7 downto 0);
	signal VGA_HS:	std_logic;
	signal VGA_R:	std_logic_vector(7 downto 0);
	signal VGA_SYNC_N:	std_logic;
	signal VGA_VS:	std_logic;
	signal GPIO_0: 	std_logic_vector(35 downto 0);
	signal GPIO_1: 	std_logic_vector(35 downto 0);

	signal reset : std_logic;
	signal clk: std_logic;

begin
	clock_driver : process
		constant period : time := 20 ns;
	begin
		clk <= '0';
		wait for period / 2;
		clk <= '1';
		wait for period / 2;
	end process clock_driver;

	simulate: process
	begin
		reset <= '1';
		wait for 70 ns;
		reset <= '0';
		wait;

		-- nothing fancy for simulation now
	end process simulate;

	CLOCK_50 <= clk;
	KEY(0) <= not reset;

	sut :  DE1_oscilloscope port map(
			ADC_CONVST, ADC_DIN,  ADC_DOUT, ADC_SCLK,
			CLOCK2_50, CLOCK3_50, CLOCK4_50, CLOCK_50,
			HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
			KEY,
			LEDR,
			SW,
			VGA_BLANK_N, VGA_B, VGA_CLK, VGA_G, VGA_HS, VGA_R, VGA_SYNC_N, VGA_VS,
			GPIO_0, GPIO_1
	);


end architecture test;
