library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 2.2 [us] cycle is triggered autonomous
-- going to 40 Mhz clock (act on rising & falling) would save ~0.1 us, but gives a bit more complexity

entity read_ADC is
	-- read the previous result, and start measurement again
	port(
		clk_50MHz : in std_logic;  -- 50 MHz clock
		reset : in std_logic;   -- should be active at least 2 50Mhz cycles, so it is not missed by 25MHz process

		/* signals to/from the LTC2308 ADC */
		ADC_CONVST:	out	std_logic;
		ADC_DIN:	out	std_logic;
		ADC_DOUT:	in	std_logic;
		ADC_SCLK:	out	std_logic;

		
		/* 12-bit data as read from ADC */
		data : out std_logic_vector(11 downto 0); -- data from measurement of previous start signal
		data_available_now : out std_logic  -- active high for 1 clock to indicate new data has arrived
	);
end entity read_ADC;

architecture RTL of read_ADC is

	type ADC_sequence_type is ( AFTER_INIT_down, WAIT_Tconv_down, SET_SD_down, GET_B11_up, SET_OS_down, get_B10_up, SET_S1_down, GET_B9_up, SET_S0_down, GET_B8_up,
		                        SET_UNI_down, GET_B7_up, SET_SLP_down, GET_B6_up, AFTER_B6_down, GET_B5_up, AFTER_B5_down, GET_B4_up,
		                        AFTER_B4_down, GET_B3_up, AFTER_B3_down, GET_B2_up, AFTER_B2_down, GET_B1_up, AFTER_B1_down,
		                        GET_B0_up, AFTER_B0_down,
		                        WAIT_Tacq2_down, WAIT_Tacq1_down, CONVST_1_down, CONVST_2_down
	);
	-- read states: e.g. OS_B11 as write OS, read B11 at falling clock edge
	
	signal last_ADC_DOUT : std_logic;
	signal data_while_reading_out : std_logic_vector(11 downto 0);
	signal countdown_Tconv : integer range 0 to 80;
	
begin
	run_sequence : process (clk_50MHz) is
		variable state : ADC_sequence_type := AFTER_INIT_down;
	begin
		if rising_edge(clk_50MHz) then
			
			ADC_CONVST <= '0';
			ADC_SCLK <= '0';
			ADC_DIN <= '-';
			data_available_now <= '0';
			
			if reset = '1' then
				-- don't change state during reset since last adc status is dislayed then
				-- but we need to measure to get good level detection to set the time axis
				state := AFTER_INIT_down;
			else
				case state is
					when AFTER_INIT_down =>
						countdown_Tconv <= 80;    -- 1.6 [us] - 40 [ns] CONVST signal
						state := WAIT_Tconv_down;  -- start a new conversion: read-out and measure sequence
					when WAIT_Tconv_down =>
						ADC_SCLK <= '0';
						if countdown_Tconv = 0 then
							state := SET_SD_down;
							countdown_Tconv <= 80;
						else
							countdown_Tconv <= countdown_Tconv - 1;
						end if;
					when SET_SD_down =>
						ADC_DIN <= '1';  -- S/D single-ended (not differential)
						state := GET_B11_up;
					when GET_B11_up =>
						ADC_DIN <= '1';  -- S/D single-ended (not differential)
						ADC_SCLK <= '1';
						data_while_reading_out(11) <= ADC_DOUT;
						state := SET_OS_down;
					when SET_OS_down =>
						ADC_DIN <= '0';  -- O/S select ODD
						state := GET_B10_up;
					when GET_B10_up =>
						ADC_DIN <= '0';  -- O/S select ODD
						ADC_SCLK <= '1';
						data_while_reading_out(10) <= ADC_DOUT;
						state := SET_S1_down;
					when SET_S1_down =>
						ADC_DIN <= '0';  -- S1 select channel 00
						state := GET_B9_up;
					when GET_B9_up =>
						ADC_DIN <= '0';  -- S1 select channel 00
						ADC_SCLK <= '1';
						data_while_reading_out(9) <= ADC_DOUT;
						state := SET_S0_down;
					when SET_S0_down =>
						ADC_DIN <= '0';  -- S0 select channel 00
						state := GET_B8_up;
					when GET_B8_up =>
						ADC_DIN <= '0';  -- S0 select channel 00
						ADC_SCLK <= '1';
						data_while_reading_out(8) <= ADC_DOUT;
						state := SET_UNI_down;
					when SET_UNI_down =>
						ADC_DIN <= '1';  -- UNIpolarmode (not 2's complement)
						state := GET_B7_up;
					when GET_B7_up =>
						ADC_DIN <= '1';  -- UNIpolarmode (not 2's complement)
						ADC_SCLK <= '1';
						data_while_reading_out(7) <= ADC_DOUT;
						state := SET_SLP_down;
					when SET_SLP_down =>
						ADC_DIN <= '0';  -- NAP/SLEEP mode, not used since CONVST is low now
						state := GET_B6_up;
					when GET_B6_up =>
						ADC_DIN <= '0';  -- NAP/SLEEP mode, not used since CONVST is low now
						ADC_SCLK <= '1';
						data_while_reading_out(6) <= ADC_DOUT;
						state := AFTER_B6_down;
					when AFTER_B6_down =>
						state := GET_B5_up;
					when GET_B5_up =>
						ADC_SCLK <= '1';
						data_while_reading_out(5) <= ADC_DOUT;
						state := AFTER_B5_down;
					when AFTER_B5_down =>
						state := GET_B4_up;
					when GET_B4_up =>
						ADC_SCLK <= '1';
						data_while_reading_out(4) <= ADC_DOUT;
						state := AFTER_B4_down;
					when AFTER_B4_down =>
						state := GET_B3_up;
					when GET_B3_up =>
						ADC_SCLK <= '1';
						data_while_reading_out(3) <= ADC_DOUT;
						state := AFTER_B3_down;
					when AFTER_B3_down =>
						state := GET_B2_up;
					when GET_B2_up =>
						ADC_SCLK <= '1';
						data_while_reading_out(2) <= ADC_DOUT;
						state := AFTER_B2_down;
					when AFTER_B2_down =>
						state := GET_B1_up;
					when GET_B1_up =>
						ADC_SCLK <= '1';
						data_while_reading_out(1) <= ADC_DOUT;
						state := AFTER_B1_down;
					when AFTER_B1_down =>
						state := GET_B0_up;
					when GET_B0_up =>
						ADC_SCLK <= '1';
						data_while_reading_out(0) <= ADC_DOUT;
						state := AFTER_B0_down;
					-- 240 ns Tacq after bit 7, so 5 bits = 5/25MHz = 200 ns, so only 40 ns needed
					when AFTER_B0_down =>
						data <= data_while_reading_out;  -- copy data to output signal
						state := WAIT_Tacq2_down;
					when WAIT_Tacq2_down =>
						data_available_now <= '1';  -- so data is safely available
						state := WAIT_Tacq1_down;
					when WAIT_Tacq1_down =>
						state := CONVST_2_down;
					when CONVST_2_down =>
						ADC_CONVST <= '1';   -- now at 260 ns, spec is >=240 ns Tacq after bit 7
						state := CONVST_1_down;
					when CONVST_1_down =>
						ADC_CONVST <= '1';
						state := WAIT_Tconv_down;
				end case;
			end if; -- reset
		end if;
	end process;


end architecture RTL;

