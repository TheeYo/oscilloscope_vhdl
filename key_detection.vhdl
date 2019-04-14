library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key_detection is
	port(
		clk : in std_logic;
		rst : in std_logic;
		KEY: in std_logic_vector(3 downto 1);
		
		button_plus_pressed_once : out std_logic;
		button_minus_pressed_once : out std_logic;
		button_control_mode_pressed_once : out std_logic;
		any_button_being_pressed : out std_logic
	);
end entity key_detection;

architecture RTL of key_detection is

	signal prev_plus_button_pressed  : std_logic;   -- 1 clock cycled delayed latched value - note buttons are debounced
	signal prev_minus_button_pressed : std_logic;
	signal latched_plus_button_pressed  : std_logic;  -- note buttons are debounced, but may change during setup time
	signal latched_minus_button_pressed : std_logic;
	signal prev_control_mode_button_pressed : std_logic;
	signal latched_control_mode_button_pressed  : std_logic;  -- coupled to KEY3, note buttons are debounced, but may change during setup time

	signal hold_counter : integer range 0 to 16777215;  -- 0.3[s]
	signal hold_counter_active : std_logic;

begin

	long_key_hold : process(clk)
	begin
		
		if rising_edge(clk) then
			if (rst = '1') then
				hold_counter_active <= '0';
			elsif (latched_plus_button_pressed = '0') and (latched_minus_button_pressed = '0') then
				hold_counter_active <= '0';
			elsif (latched_plus_button_pressed = '1'  and prev_plus_button_pressed = '0') or 
				  (latched_minus_button_pressed = '1' and prev_minus_button_pressed = '0') then
				hold_counter <= 16#FFFFFF#;
				hold_counter_active <= '1';
			elsif hold_counter_active = '1' then
				if hold_counter = 0 then
					hold_counter <= 16#7FFFF#;
				else
					hold_counter <= hold_counter - 1;
				end if;
			end if;
		end if;
	end process;

	button_detection: process(clk)
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				latched_control_mode_button_pressed <= '0';
				latched_plus_button_pressed <= '0';
				latched_minus_button_pressed <= '0';

				prev_control_mode_button_pressed <= '0';
				prev_plus_button_pressed  <= '0';
				prev_minus_button_pressed <= '0';

				button_plus_pressed_once <= '0';
				button_minus_pressed_once <= '0';
				button_control_mode_pressed_once <= '0';
				
				any_button_being_pressed <= '0';
			else
				latched_plus_button_pressed  <= not KEY(1);   -- latch since KEY(1..4) may change at any time, and 0=pressed
				latched_minus_button_pressed <= not KEY(2);
				latched_control_mode_button_pressed <= not KEY(3);

				prev_control_mode_button_pressed <= latched_control_mode_button_pressed;
				prev_plus_button_pressed  <= latched_plus_button_pressed;
				prev_minus_button_pressed <= latched_minus_button_pressed;

				button_plus_pressed_once <= latched_plus_button_pressed and not prev_plus_button_pressed;
				button_minus_pressed_once <= latched_minus_button_pressed and not prev_minus_button_pressed;
				button_control_mode_pressed_once <= latched_control_mode_button_pressed and not prev_control_mode_button_pressed;

				if (hold_counter_active = '1') and (hold_counter = 0) then
					button_plus_pressed_once  <= latched_plus_button_pressed;
					button_minus_pressed_once <= latched_minus_button_pressed;
				end if;
				
				any_button_being_pressed <= latched_control_mode_button_pressed or latched_plus_button_pressed or latched_minus_button_pressed;
			end if;
		end if;
		
	end process;


end architecture RTL;
