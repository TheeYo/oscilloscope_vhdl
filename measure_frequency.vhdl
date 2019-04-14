library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity measure_frequency is
	port(
		clk : in std_logic;
		rst : in std_logic;
		one_cycle_reset : in std_logic;
		trigger_detected : in std_logic;
		
		measured_frequency: out integer range 0 to 64e3 -- ADC does <500 [KS/s], and need time (14 samples) to measure (hi&how)
	);
end entity measure_frequency;

architecture RTL of measure_frequency is

	signal measure_frequency_trigger_counter : integer range 0 to 64e3;
	signal measure_frequency_countdown : integer range 0 to 50e6; -- count duration 1[s] for measured_frequency
	
begin
	frequency_measure_process : process(clk)
	begin
		if rising_edge(clk) then
			if one_cycle_reset = '1' then
				measured_frequency <= 0;
				measure_frequency_countdown <= 0;
				measure_frequency_trigger_counter <= 0;
			else
				if (measure_frequency_countdown = 0) then
					if rst = '1' then  -- quick frequency estimate for higher frequencies to set time axis
						measure_frequency_countdown <= (50e6/16); -- after 1/16 [s] already a value
	 					measured_frequency <= measure_frequency_trigger_counter*16;
					else
						measure_frequency_countdown <= 50e6;
	 					measured_frequency <= measure_frequency_trigger_counter;
					end if;
					measure_frequency_trigger_counter <= 0;
 				else
 					measure_frequency_countdown <= measure_frequency_countdown - 1;
 					if (trigger_detected = '1') then
 						measure_frequency_trigger_counter <= measure_frequency_trigger_counter + 1;
 					end if;
				end if;
			end if;
		end if;
	end process;
	
end architecture RTL;
