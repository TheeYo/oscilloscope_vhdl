
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;


/*
 * button 0: press for reset (during reset button press, one sample is shown, so press a few times to see the stability ADC samples)
 * button 1: increase
 * button 2: decrease
 * button 3: control mode selection - cycle through:
 *     ACTUAL_V (default, return after some seconds)
 *     FREQUENCY (trigger level should be set OK)
 *     TIME_PER_DIV (can use button 1&2)
 *     CONTROL_MODE_TRIGGER_LEVEL (can use button 1&2 to change trigger level, but only reset can undo user set to default
 *            (default= avg sensed V since last reset: (min+max)/2 ). indicated by 3 horizontal lines
 *            When set typ the user, only a minus sign is given
 *     MIN V
 *     MAX V
 * 
 * switch 0: trigger on level rising
 * switch 1: trigger level enabled
 * 
 * led 0: =switch 0 - on means to trigger on rising signal
 * led 1: on=trigger level enabled
 * led 2: on=waiting for trigger to occur
 * led 3: on=could trigger now
 * 
 * input for ADC:
 * + top left = ground
 * + bottom right = VDD
 * + bottom left = ADC input signal
 */


entity DE1_oscilloscope is
        port( 
				/*      ADC      */
				ADC_CONVST:	out	std_logic;
				ADC_DIN:	out	std_logic;
				ADC_DOUT:	in	std_logic;
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
end DE1_oscilloscope;


architecture structure of DE1_oscilloscope is

	component calc_bin_to_6x7seg is
		port(
			binaryNumber : in std_logic_vector(19 downto 0);  -- 2^20 > 999.999 (max on 6 segments)
			HEX0: out std_logic_vector(6 downto 0);
			HEX1: out std_logic_vector(6 downto 0);
			HEX2: out std_logic_vector(6 downto 0);
			HEX3: out std_logic_vector(6 downto 0);
			HEX4: out std_logic_vector(6 downto 0);
			HEX5: out std_logic_vector(6 downto 0)
			-- TODO: add enumeration for display mode
			-- type display_6x7seg_mode_type is {FULL, ACTUAL_VOLTAGE, ...};
			-- put this in a separate package to make it available to other modules
		);
	end component;
	
	component read_ADC
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
	end component read_ADC;

    component display_via_memory
    	port(
			clk_50MHz : in std_logic;   -- clock for pixel input
			reset : in std_logic;
	
			pixel_X   : in std_logic_vector(10 downto 0);
			pixel_Y   : in std_logic_vector(9 downto 0);
			pixel_value_R : in std_logic_vector(7 downto 0);
			pixel_value_G : in std_logic_vector(7 downto 0);
			pixel_value_B : in std_logic_vector(7 downto 0);
			pixel_valid : in std_logic;  -- set to 1 means X,Y and pixel_value_[RGB] are valid
	
			/* --- VGA output --- */
			VGA_BLANK_N: out std_logic;
			VGA_B:	out std_logic_vector(7 downto 0);
			VGA_CLK:	out std_logic;
			VGA_G:	out std_logic_vector(7 downto 0);
			VGA_HS:	out std_logic;
			VGA_R:	out std_logic_vector(7 downto 0);
			VGA_SYNC_N:	out std_logic;
			VGA_VS:	out std_logic
		);
	end component display_via_memory;

	component key_detection is
		port(
			clk : in std_logic;
			rst : in std_logic;
			KEY: in std_logic_vector(3 downto 1);
			
			button_plus_pressed_once : out std_logic;
			button_minus_pressed_once : out std_logic;
			button_control_mode_pressed_once : out std_logic;
			any_button_being_pressed : out std_logic
		);
	end component key_detection;

	component measure_frequency is
		port(
			clk : in std_logic;
			rst : in std_logic;
			one_cycle_reset : in std_logic;
			
			trigger_detected : in std_logic;
			
			measured_frequency: out integer range 0 to 64e3 -- ADC does <500 [KS/s], and need time (14 samples) to measure (hi&how)
		);
	end component measure_frequency;

	component signal_generator is
		port(
			clk : in std_logic;
			signals : out std_logic_vector(5 downto 0)
		);
	end component signal_generator;

	signal overall_reset : std_logic;

    signal number2convert : std_logic_vector(19 downto 0);

	signal pixel_X   : std_logic_vector(10 downto 0);
	signal pixel_Y   : std_logic_vector(9 downto 0);
	signal pixel_value_R : std_logic_vector(7 downto 0);
	signal pixel_value_G : std_logic_vector(7 downto 0);
	signal pixel_value_B : std_logic_vector(7 downto 0);
	signal pixel_valid : std_logic;

	signal pixel_X_for_measurement : integer range 0 to 1440-1;
	signal pixel_Y_for_measurement : integer range 0 to 900-1;
	signal pixel_X_countdown : integer range 0 to 1000000-1;
	
	signal pixel_X_countdown_initial_value : integer range 0 to 1000000-1 := 50000-1;   -- 50K is 0.1[s]/div of 100 pixels
    /* pixel_X_countdown_initial_value
     * 12   1e6 -    2[s]/div   (screen 14.4 div = 28.8[s]
     * 11 500e3 -    1[s]/div
     * 10 250e3 -  500[ms]/div
     * 9  100e3 -  200[ms]/div  (default)  up to 50 Hz (10 X samples/period) >64
     * 8   50e3 -  100[ms]/div                  100 Hz                       >128
     * 7   25e3 -   50[ms]/div                  200 Hz                       >256
     * 6   10e3 -   20[ms]/div                  500 Hz                       >512
     * 5   5e3 -    10[ms]/div                 1000 Hz                       >1024
     * 4   2.5e3-    5[ms]/div                 2000 Hz
     * 3   1e3 -     2[ms]/div                 5000 Hz
     * 2   500 -     1[ms]/div  (screen 14.4 div = 14.4[ms]
     * 1   250 -   500[us]/div  (screen 14.4 div = 7.2[ms], but <1 measurement per pixel)
     * 0   100 -   200[us]/div  (screen 14.4 div = [ms], but <1 measurement per pixel)
    */
--    type time_per_div_setting_type is (S2, S1, MS500, MS250, MS100, MS50, MS25, MS10, MS5, MS2, MS1);  
--	signal time_per_div_setting : time_per_div_setting_type := S1;
    signal time_per_div_setting : integer range 0 to 12 := 8;

	signal button_plus_pressed_once : std_logic;  
	signal button_minus_pressed_once : std_logic;
	signal button_control_mode_pressed_once : std_logic;
	signal any_button_pressed : std_logic;
	
	signal reset_button_was_pressed_prev_clock_cycle : std_logic;
	signal reset_button_pressed_once : std_logic;
	
	-- control model to define context for keys and 7 segmented display
	type control_mode_type is (CONTROL_MODE_ACTUAL_V, CONTROL_MODE_FREQUENCY, CONTROL_MODE_TIME_PER_DIV, CONTROL_MODE_TRIGGER_LEVEL, CONTROL_MODE_MAX_ADC, CONTROL_MODE_MIN_ADC);
	signal control_mode :  control_mode_type; 
	signal control_keep_mode_countdown : integer range 0 to 200e6;  -- (4[s] @ 50MHz)
	
	signal measured_frequency : integer range 0 to 64e3; -- ADC does <500 [KS/s], and need time (14 samples) to measure (hi&how)
	
	signal adc_data : std_logic_vector(11 downto 0);
	signal adc_data_available_now : std_logic;
	
	signal adc_data_sample_when_reset_just_pressed : std_logic_vector(11 downto 0);

	signal max_adc_data : std_logic_vector(11 downto 0);
	signal min_adc_data : std_logic_vector(11 downto 0);
	signal avg_adc_value : std_logic_vector(11 downto 0);
	signal trigger_level_set_by_user : std_logic := '0';
	signal trigger_level_enabled : std_logic := '0';
	signal trigger_level : std_logic_vector(11 downto 0);
	signal trigger_level_rising : std_logic;
	signal trigger_now : std_logic;   -- 1 cycle active when trigger has been detected
	signal sample_level_counter : integer range 0 to 7 := 0;
	signal level_other_side_done : std_logic;   -- if trigger level rising, then this indicates signal was long enough below trigger level (if trigger level falling, then above trigger level)
	

	signal currentYisADCdata : std_logic := '0';
	
	-- calc_HEX_X is output as calculated from a number
	signal calc_HEX_0 : std_logic_vector(6 downto 0);
	signal calc_HEX_1 : std_logic_vector(6 downto 0);
	signal calc_HEX_2 : std_logic_vector(6 downto 0);
	signal calc_HEX_3 : std_logic_vector(6 downto 0);
	signal calc_HEX_4 : std_logic_vector(6 downto 0);
	signal calc_HEX_5 : std_logic_vector(6 downto 0);

	-- calc_HEX_X is output as calculated from a number
	signal time_per_div_HEX_0 : std_logic_vector(6 downto 0);
	signal time_per_div_HEX_1 : std_logic_vector(6 downto 0);
	signal time_per_div_HEX_2 : std_logic_vector(6 downto 0);
	signal time_per_div_HEX_3 : std_logic_vector(6 downto 0);
	signal time_per_div_HEX_4 : std_logic_vector(6 downto 0);
	signal time_per_div_HEX_5 : std_logic_vector(6 downto 0);
	
begin
	overall_reset <= not KEY(0);
	trigger_level_rising <= SW(0);
	LEDR(0) <= SW(0);
	LEDR(1) <= trigger_level_enabled;
	LEDR(3) <= trigger_now;
	LEDR(9 downto 4) <= b"000000";
	
	reset_key_pressed: process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			reset_button_was_pressed_prev_clock_cycle <= overall_reset;
			reset_button_pressed_once <= overall_reset and not reset_button_was_pressed_prev_clock_cycle;
		end if;
	end process;
	

--	HEX2 <= (others => '1');  -- off
--	HEX3 <= (others => overall_reset);
--	HEX4 <= (others => overall_reset);
	
	-- GPIO 1 is at right edge of board
	--    botton right on GPIO  = GPIO_1_D35 = pin 40
	--    botton left on GPIO = GPIO_1_D34 = pin 39
	--    botton right on board, second pin = GPIO_0_D2 = pin 38
	--    botton left on board, second pin = GPIO_0_D3 = pin 37
	--    (ground is at 6th pin counting from top on right side = pin12  ...)
	--    see data sheet
	signal_creation : signal_generator port map(CLOCK_50, GPIO_1(35 downto 30));
	GPIO_1(29) <= '1';   -- 3.3 V
	
    disp_via_mem : display_via_memory port map(
    		clk_50MHz => CLOCK_50, 
			reset => overall_reset,

            -- pixel data to set in memory
			pixel_X => pixel_X, pixel_Y => pixel_Y,
			pixel_value_R => pixel_value_R, pixel_value_G => pixel_value_G,	pixel_value_B => pixel_value_B,
			pixel_valid   => pixel_valid,
	
			/* --- VGA output --- */
		    VGA_BLANK_N => VGA_BLANK_N, VGA_SYNC_N => VGA_SYNC_N,
		    VGA_HS => VGA_HS, VGA_VS => VGA_VS,
		    VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B,
		    VGA_CLK => VGA_CLK );

    input_keys: key_detection port map(
			clk => CLOCK_50,
			rst => overall_reset,
			KEY => KEY(3 downto 1),
			
			button_plus_pressed_once => button_plus_pressed_once,
			button_minus_pressed_once => button_minus_pressed_once,
			button_control_mode_pressed_once => button_control_mode_pressed_once,
			any_button_being_pressed => any_button_pressed
    );


	frequency_measure_process : measure_frequency
		port map(
			clk                => CLOCK_50,
			rst                => overall_reset,
			one_cycle_reset    => reset_button_pressed_once,
			trigger_detected   => trigger_now,
			measured_frequency => measured_frequency
		);


	readADC : read_ADC port map( clk_50MHz => CLOCK_50, reset => reset_button_pressed_once,
		                         ADC_CONVST => ADC_CONVST, ADC_DIN => ADC_DIN, ADC_DOUT => ADC_DOUT, ADC_SCLK => ADC_SCLK,
		                         data => adc_data, data_available_now => adc_data_available_now );
	
	
	adc_data_for_reset: process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) and (reset_button_pressed_once = '1') then
			adc_data_sample_when_reset_just_pressed <= adc_data;
		end if;
	end process;
	
	number2convert <= (b"00000000" & adc_data) when (control_mode = CONTROL_MODE_ACTUAL_V) and (overall_reset = '0') else
			          (b"00000000" & adc_data_sample_when_reset_just_pressed) when (control_mode = CONTROL_MODE_ACTUAL_V) else
	                  (b"00000000" & trigger_level) when (control_mode = CONTROL_MODE_TRIGGER_LEVEL) else
	                  std_logic_vector(to_unsigned(measured_frequency, 20)) when (control_mode = CONTROL_MODE_FREQUENCY) else
	                  (b"00000000" & max_adc_data) when (control_mode = CONTROL_MODE_MAX_ADC) else
	                  (b"00000000" & min_adc_data) when (control_mode = CONTROL_MODE_MIN_ADC) else
	                  b"00000000000000000000";   -- don't care since time_per_div will be on display, but put 0's for lower power usage
	calc_seg : calc_bin_to_6x7seg port map(
		binaryNumber => number2convert,
		HEX0 => calc_HEX_0,
		HEX1 => calc_HEX_1,
		HEX2 => calc_HEX_2,
		HEX3 => calc_HEX_3,
		HEX4 => calc_HEX_4,   -- max value of ADC is 4096, so no need for MSB display (value is 0)
		HEX5 => calc_HEX_5
	);

	-- output_to_7seg_display
	HEX0 <= time_per_div_HEX_0 when (control_mode = CONTROL_MODE_TIME_PER_DIV) else
	        calc_HEX_0 when (control_mode = CONTROL_MODE_FREQUENCY) else
            (not "0111110"); -- V for voltage
	HEX1 <= time_per_div_HEX_1 when (control_mode = CONTROL_MODE_TIME_PER_DIV) else
	        calc_HEX_1 when (control_mode = CONTROL_MODE_FREQUENCY) else
            (not "0000000") when (control_mode = CONTROL_MODE_ACTUAL_V) else -- empty
            (not "0001000") when (control_mode = CONTROL_MODE_MIN_ADC) else  -- low _
            (not "0000001") when (control_mode = CONTROL_MODE_MAX_ADC) else  -- high _
            (not "1000000") when (control_mode = CONTROL_MODE_TRIGGER_LEVEL) and (trigger_level_set_by_user = '1') else
            (not "1001001");     -- 3 horizontal lines when trigger level determined from min/max
	HEX2 <= time_per_div_HEX_2 when (control_mode = CONTROL_MODE_TIME_PER_DIV) else
	        calc_HEX_2 when (control_mode = CONTROL_MODE_FREQUENCY) else
            calc_HEX_0;   -- TRIGGER_LEVEL or ACTUAL_VOLTAGE
	HEX3 <= time_per_div_HEX_3 when (control_mode = CONTROL_MODE_TIME_PER_DIV) else
	        calc_HEX_3 when (control_mode = CONTROL_MODE_FREQUENCY) else
            calc_HEX_1;   -- TRIGGER_LEVEL or ACTUAL_VOLTAGE
	HEX4 <= time_per_div_HEX_4 when (control_mode = CONTROL_MODE_TIME_PER_DIV) else
	        calc_HEX_4 when (control_mode = CONTROL_MODE_FREQUENCY) else
            calc_HEX_2;   -- TRIGGER_LEVEL or ACTUAL_VOLTAGE
	HEX5 <= time_per_div_HEX_5 when (control_mode = CONTROL_MODE_TIME_PER_DIV) else
	        calc_HEX_5 when (control_mode = CONTROL_MODE_FREQUENCY) else
            calc_HEX_3;   -- TRIGGER_LEVEL or ACTUAL_VOLTAGE

	

	control_mode_handling: process(CLOCK_50)
		variable prev_control_mode_button_pressed : std_logic;
		variable latched_control_mode_button_pressed  : std_logic;  -- coupled to KEY3, note buttons are debounced, but may change during setup time
	begin
		if rising_edge(CLOCK_50) then
			if (overall_reset = '1') then
				control_mode <= CONTROL_MODE_ACTUAL_V;
				control_keep_mode_countdown <= 0;
			else
				if button_control_mode_pressed_once then
					-- ORDER: CONTROL_MODE_ACTUAL_V, CONTROL_MODE_FREQUENCY, CONTROL_MODE_TIME_PER_DIV, CONTROL_MODE_TRIGGER_LEVEL
					if control_mode = CONTROL_MODE_ACTUAL_V then
						control_mode <= CONTROL_MODE_FREQUENCY;
					elsif control_mode = CONTROL_MODE_FREQUENCY then
						control_mode <= CONTROL_MODE_TIME_PER_DIV;
					elsif control_mode = CONTROL_MODE_TIME_PER_DIV then
						control_mode <= CONTROL_MODE_TRIGGER_LEVEL;
					elsif control_mode = CONTROL_MODE_TRIGGER_LEVEL then
						control_mode <= CONTROL_MODE_MIN_ADC;
					elsif control_mode = CONTROL_MODE_MIN_ADC then
						control_mode <= CONTROL_MODE_MAX_ADC;
					else
						control_mode <= CONTROL_MODE_ACTUAL_V;
					end if;

--	Works, but error in Quartus:	control_mode <= CONTROL_MODE_TIME_PER_DIV WHEN control_mode = CONTROL_MODE_ACTUAL_V ELSE
--					                CONTROL_MODE_TRIGGER_LEVEL WHEN control_mode = CONTROL_MODE_TIME_PER_DIV ELSE
--					                CONTROL_MODE_ACTUAL_V;

				elsif (button_minus_pressed_once = '1' or button_plus_pressed_once = '1') and (control_mode /= CONTROL_MODE_TRIGGER_LEVEL) then
					control_mode <= CONTROL_MODE_TIME_PER_DIV;
				end if;

				-- after 4[s] of inactivity, return to displaying the actual voltage when busy with +/- buttons
				if any_button_pressed then
					control_keep_mode_countdown <= 200e6;
				elsif (control_keep_mode_countdown > 0) then
					control_keep_mode_countdown <= control_keep_mode_countdown - 1;
				elsif (control_keep_mode_countdown = 0) and (control_mode /= CONTROL_MODE_FREQUENCY) then
					control_mode <= CONTROL_MODE_ACTUAL_V;
				end if;
				
			end if;
		end if;
	end process;

	
	set_trigger_level: process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			if (reset_button_pressed_once) then
				trigger_level_set_by_user <= '0';   -- only reset can undo the setting of trigger level by user
			elsif (control_mode = CONTROL_MODE_TRIGGER_LEVEL) then
				if not trigger_level_set_by_user then
					trigger_level <= avg_adc_value;
				end if;
					
				if button_plus_pressed_once then
					trigger_level_set_by_user <= '1';
					if ( unsigned(trigger_level) < 4092) then
						trigger_level <= std_logic_vector(to_unsigned( (to_integer(unsigned(trigger_level)) + 1), trigger_level'length));
					end if;
				elsif button_minus_pressed_once then
					trigger_level_set_by_user <= '1';
					if (unsigned(trigger_level) > 4) then
						trigger_level <= std_logic_vector(to_unsigned( (to_integer(unsigned(trigger_level)) - 1), trigger_level'length));
					end if;
				end if;
			end if;
		end if;
	end process;
		

	set_time_in_X: process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			if (overall_reset = '1') then
				-- set display frequency high enough so user will not get an aliasing problem
				-- meaning e.g. a horizontal line for signal that is a multiple of the DISPLAYED sample frequency
				if    measured_frequency >= 16#1000# then
					time_per_div_setting <= 0;
				elsif measured_frequency >= 16#800# then
					time_per_div_setting <= 1;
				elsif measured_frequency >= 16#400# then
					time_per_div_setting <= 2;
				elsif measured_frequency >= 16#200# then
					time_per_div_setting <= 3;
				elsif measured_frequency >= 16#100# then
					time_per_div_setting <= 4;
				elsif measured_frequency >= 16#80# then
					time_per_div_setting <= 5;
				elsif measured_frequency >= 16#40# then
					time_per_div_setting <= 6;
				elsif measured_frequency >= 16#20# then
					time_per_div_setting <= 7;
				else
					time_per_div_setting <= 8;   -- 0.1 [s/div]
				end if;
			else
				if control_mode = CONTROL_MODE_TIME_PER_DIV then
					if button_plus_pressed_once then
						if (time_per_div_setting < 11) then
							time_per_div_setting <= time_per_div_setting + 1;
						end if;
					elsif button_minus_pressed_once then
						if (time_per_div_setting > 0) then
							time_per_div_setting <= time_per_div_setting - 1;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- set pixel_X_countdown_initial_value depending on  
	set_time_per_div: process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
-- next lines do not work in Quartus:
--			with time_per_div_setting select
--				pixel_X_countdown_initial_value <= 500  -1 WHEN 0,
--				                                     1e3-1 WHEN 1,
--				                                     2e3-1 WHEN 2,
--				                                     5e3-1 WHEN 3,
--				                                    10e3-1 WHEN 4,
--				                                    20e3-1 WHEN 5,
--				                                    50e3-1 WHEN 6,
--				                                   100e3-1 WHEN 7,
--				                                   200e3-1 WHEN 8,
--				                                   500e3-1 WHEN 9,
--				                                     1e6-1 WHEN others;

			if time_per_div_setting = 0 then
				pixel_X_countdown_initial_value <= 100-1;
			elsif time_per_div_setting = 1 then
				pixel_X_countdown_initial_value <= 250-1;
			elsif time_per_div_setting = 2 then
				pixel_X_countdown_initial_value <= 500-1;
			elsif time_per_div_setting = 3 then
				pixel_X_countdown_initial_value <=1000-1;
			elsif time_per_div_setting = 4 then
				pixel_X_countdown_initial_value <=2500-1;
			elsif time_per_div_setting = 5 then
				pixel_X_countdown_initial_value <=   5e3-1;
			elsif time_per_div_setting = 6 then
				pixel_X_countdown_initial_value <=  10e3-1;
			elsif time_per_div_setting = 7 then
				pixel_X_countdown_initial_value <=  25e3-1;
			elsif time_per_div_setting = 8 then
				pixel_X_countdown_initial_value <=  50e3-1;
			elsif time_per_div_setting = 9 then
				pixel_X_countdown_initial_value <= 100e3-1;
			elsif time_per_div_setting = 10 then
				pixel_X_countdown_initial_value <= 250e3-1;
			elsif time_per_div_setting = 11 then
				pixel_X_countdown_initial_value <= 500e3-1;
			else
				pixel_X_countdown_initial_value <= 1e6-1;
			end if;
		end if;
	end process;

	calc_hex_from_time_per_div_setting: process(time_per_div_setting)
	begin
		
		if (time_per_div_setting = 12) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "0000000";
			time_per_div_HEX_3 <= not "1011011";  -- 2
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "0111111";  -- 0
			time_per_div_HEX_0 <= not "0000000";
		elsif (time_per_div_setting = 11) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "0000000";
			time_per_div_HEX_3 <= not "0000110";  -- 1
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "0111111";  -- 0
			time_per_div_HEX_0 <= not "0000000";
		elsif (time_per_div_setting = 10) then
			time_per_div_HEX_5 <= not "1101101";  -- 5
			time_per_div_HEX_4 <= not "0111111";  -- 0
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 9) then
			time_per_div_HEX_5 <= not "1011011";  -- 2
			time_per_div_HEX_4 <= not "0111111";  -- 0
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 8) then
			time_per_div_HEX_5 <= not "0000110";  -- 1
			time_per_div_HEX_4 <= not "0111111";  -- 0
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 7) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "1101101";  -- 5
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 6) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "1011011";  -- 2
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 5) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "0000110";  -- 1
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 4) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "0000000";
			time_per_div_HEX_3 <= not "1101101";  -- 5
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 3) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "0000000";
			time_per_div_HEX_3 <= not "1011011";  -- 2
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 2) then
			time_per_div_HEX_5 <= not "0000000";
			time_per_div_HEX_4 <= not "0000000";
			time_per_div_HEX_3 <= not "0000110";  -- 1
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1001111";  -- 3
		elsif (time_per_div_setting = 1) then
			time_per_div_HEX_5 <= not "1101101";  -- 5
			time_per_div_HEX_4 <= not "0111111";  -- 0
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1111101";  -- 6
		elsif (time_per_div_setting = 0) then
			time_per_div_HEX_5 <= not "1011011";  -- 2
			time_per_div_HEX_4 <= not "0111111";  -- 0
			time_per_div_HEX_3 <= not "0111111";  -- 0
			time_per_div_HEX_2 <= not "1111001";  -- E
			time_per_div_HEX_1 <= not "1000000";  -- -
			time_per_div_HEX_0 <= not "1111101";  -- 6
		else
			time_per_div_HEX_5 <= not "1111001";  -- E
			time_per_div_HEX_4 <= not "1010000";  -- r
			time_per_div_HEX_3 <= not "1010000";  -- r
			time_per_div_HEX_2 <= not "1011100";  -- o
			time_per_div_HEX_1 <= not "1010000";  -- r
			time_per_div_HEX_0 <= not "0000000";
		end if;
	end process;


	determine_avg_adc_value : process(CLOCK_50)
		variable count_max_in_a_row : integer range 0 to 7 := 0;
		variable count_min_in_a_row : integer range 0 to 7 := 0;
	begin
		if rising_edge(CLOCK_50) then
			if (overall_reset = '1') then
				min_adc_data <= 12b"111111111100";
				max_adc_data <= 12b"000000000011";
				avg_adc_value <= 12b"011111111111";
				count_min_in_a_row := 0;
				count_max_in_a_row := 0;
			else
				if adc_data_available_now then
					if to_integer(unsigned(adc_data)) > to_integer(unsigned(max_adc_data)) then
						if (count_max_in_a_row = 7) then
							max_adc_data <= adc_data; -- was: adc_data, but spikes have too much impact
							count_max_in_a_row := 0;   -- to prevent rising signal with 1 outlier to give wrong value
						else
							count_max_in_a_row := count_max_in_a_row + 1;
						end if;
					else
						count_max_in_a_row := 0;
					end if;
					if to_integer(unsigned(adc_data)) < to_integer(unsigned(min_adc_data)) then
						if (count_min_in_a_row = 7) then
							min_adc_data <= adc_data; -- was: adc_data, but spikes have too much impact
							count_min_in_a_row := 0;   -- to prevent rising signal with 1 outlier to give wrong value
						else
							count_min_in_a_row := count_min_in_a_row + 1;
						end if;
					else
						count_min_in_a_row := 0;
					end if;
				end if;
				
				avg_adc_value <= std_logic_vector( to_unsigned( ( to_integer(unsigned(min_adc_data)) +
					                                              to_integer(unsigned(max_adc_data))   )/2, adc_data'length) );
			end if;
		end if;
	end process;
	

	manage_trigger_level : process(CLOCK_50)
		variable sum_min_max : integer range 0 to 4095*2;
	begin
		if rising_edge(CLOCK_50) then
			if reset_button_pressed_once then   -- so signal trigger_now is available during reset button press (for freq. for default timescale)
				trigger_now <= '0';
				trigger_level_enabled <= '0';
				sample_level_counter <= 0;
				level_other_side_done <= '0';
			else
				trigger_level_enabled <= SW(1);
				-- set min/max adc value since reset, and determine trigger level from that.
				-- note that trigger_now is active for only 1 clock cycle.
				trigger_now <= '0';
				if adc_data_available_now then
					sample_level_counter <= 0;  -- value may toggle between X and X+1. If X or X+1 is trigger level, reset counter
					if ( to_integer(unsigned(adc_data)) > to_integer(unsigned(trigger_level))+1 ) then
						if trigger_level_rising and level_other_side_done then
							if sample_level_counter = 1 then
								trigger_now <= '1';
								level_other_side_done <= '0';
								sample_level_counter <= 0;
							else
								sample_level_counter <= sample_level_counter + 1;
							end if;
						elsif trigger_level_rising and not level_other_side_done then
							sample_level_counter <= 0;
						elsif (not trigger_level_rising) and level_other_side_done then
							sample_level_counter <= 0;
						else -- (not trigger_level_rising) and (not level_other_side_done)
							if sample_level_counter = 1 then
								level_other_side_done <= '1';
								sample_level_counter <= 0;
							else
								sample_level_counter <= sample_level_counter + 1;
							end if;
						end if;
					end if;
					
					if ( to_integer(unsigned(adc_data)) < to_integer(unsigned(trigger_level))-1 ) then
						if (not trigger_level_rising) and level_other_side_done then
							if sample_level_counter = 1 then
								trigger_now <= '1';
								level_other_side_done <= '0';
								sample_level_counter <= 0;
							else
								sample_level_counter <= sample_level_counter + 1;
							end if;
						elsif (not trigger_level_rising) and not level_other_side_done then
							sample_level_counter <= 0;
						elsif trigger_level_rising and level_other_side_done then
							sample_level_counter <= 0;
						else -- trigger_level_rising and (not level_other_side_done)
							if sample_level_counter = 1 then
								level_other_side_done <= '1';
								sample_level_counter <= 0;
							else
								sample_level_counter <= sample_level_counter + 1;
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
		
	end process;


	set_pixels : process(CLOCK_50)
	begin
		if rising_edge(CLOCK_50) then
			pixel_valid <= '0';
    		if (overall_reset = '1') then
    			LEDR(2) <= '0';
    			pixel_X_countdown <= pixel_X_countdown_initial_value;
    			pixel_X_for_measurement <= 1;
/*     		elsif pixel_X_countdown = 1 then  -- clear 100 pixels ahead
    			pixel_X <= std_logic_vector(to_unsigned( (pixel_X_for_measurement+100) mod 1440, 11));
    			pixel_Y <= 10b"1011111111";   -- 1023 means the screen Y position never matches (so not displayed on screen)
    			pixel_value_R <= "00000000";  -- RGB are not used in display_via_memory now
    			pixel_value_G <= "00000000";
    			pixel_value_B <= "00000000";
    			pixel_valid <= '1';
*/    		elsif (pixel_X_countdown = 1) then
				if ((trigger_level_enabled = '0') or (trigger_now = '1') or (pixel_X_for_measurement /= 0)) then   -- countdown remains 1 when waiting for trigger
					-- prepare: first do calculations since 899-ADC/5 may be on critical timing path
	    			if pixel_X_for_measurement < 1440-1 then
		    			pixel_X_for_measurement <= pixel_X_for_measurement + 1;
		    		else
		    			pixel_X_for_measurement <= 0;  -- start again from left of the screen
		    		end if;
	    			-- better: while measuring at this X pixel, set all measured values
	    			-- increment array of all possible values, stop measurements at value 255, and then show
	    			
	    			-- now: just copy value that happens to be there at the end of the countdown (so 1 measurement per X on screen)
	    			
	    			pixel_Y_for_measurement <= (to_integer(unsigned(adc_data))+2)/5; -- so value is 0..819  (=4095/5)
	    			pixel_X_countdown <= 0;

	    			LEDR(2) <= '0';  -- LED1 is off to indicate we are not waiting for a trigger
	    		else
	    			-- countdown remains 1 when waiting for trigger
	    			LEDR(2) <= '1';  -- LED1 is on to indicate we are waiting for a trigger
	    		end if;

			elsif pixel_X_countdown = 0 then
    			pixel_X_countdown <= pixel_X_countdown_initial_value;
    			pixel_X <= std_logic_vector(to_unsigned(pixel_X_for_measurement, 11));
    			if (pixel_X_for_measurement /= 0) then
	    			pixel_Y <= std_logic_vector(to_unsigned(pixel_Y_for_measurement, 10));
	    		else
	    			pixel_Y <= std_logic_vector(to_unsigned(  (to_integer(unsigned(trigger_level))+2)/5,  10));
	    		end if;
    			pixel_value_R <= "11111111";
    			pixel_value_G <= "11111111";
    			pixel_value_B <= "11111111";
    			pixel_valid <= '1';
    		else
    			pixel_X_countdown <= pixel_X_countdown - 1;
    		end if;
		end if;
	end process;
	
    
end structure;




/* Original generated system builder code below.

//=======================================================
//  This code is generated by Terasic System Builder
//=======================================================

module DE1_oscilloscope(

	//////////// ADC //////////
	output		          		ADC_CONVST,
	output		          		ADC_DIN,
	input 		          		ADC_DOUT,
	output		          		ADC_SCLK,

	//////////// CLOCK //////////
	input 		          		CLOCK2_50,
	input 		          		CLOCK3_50,
	input 		          		CLOCK4_50,
	input 		          		CLOCK_50,

	//////////// SEG7 //////////
	output		     [6:0]		HEX0,
	output		     [6:0]		HEX1,
	output		     [6:0]		HEX2,
	output		     [6:0]		HEX3,
	output		     [6:0]		HEX4,
	output		     [6:0]		HEX5,

	//////////// KEY //////////
	input 		     [3:0]		KEY,

	//////////// LED //////////
	output		     [9:0]		LEDR,

	//////////// SW //////////
	input 		     [9:0]		SW,

	//////////// VGA //////////
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B,
	output		          		VGA_CLK,
	output		     [7:0]		VGA_G,
	output		          		VGA_HS,
	output		     [7:0]		VGA_R,
	output		          		VGA_SYNC_N,
	output		          		VGA_VS,

	//////////// GPIO_0, GPIO_0 connect to GPIO Default //////////
	inout 		    [35:0]		GPIO_0,

	//////////// GPIO_1, GPIO_1 connect to GPIO Default //////////
	inout 		    [35:0]		GPIO_1
);



//=======================================================
//  REG/WIRE declarations
//=======================================================




//=======================================================
//  Structural coding
//=======================================================



endmodule
*/
