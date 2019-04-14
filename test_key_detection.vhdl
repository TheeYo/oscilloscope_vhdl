library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_key_detection is
end entity test_key_detection;

architecture RTL of test_key_detection is
	
	component key_detection is port(
			clk : in std_logic;
			rst : in std_logic;
			KEY: in std_logic_vector(3 downto 1);
			
			button_plus_pressed_once : out std_logic;
			button_minus_pressed_once : out std_logic;
			button_control_mode_pressed_once : out std_logic;
			any_button_being_pressed : out std_logic
		);
	end component key_detection;
	
	
	signal button_plus_pressed_once : std_logic;  
	signal button_minus_pressed_once : std_logic;
	signal button_control_mode_pressed_once : std_logic;
	signal any_button_pressed : std_logic;
	signal KEY : std_logic_vector(3 downto 1);
	signal clk : std_logic;
	signal rst : std_logic;
	
begin
	clock_driver : process
		constant period : time := 20 ns;
	begin
		clk <= '0';
		wait for period / 2;
		clk <= '1';
		wait for period / 2;
	end process clock_driver;

    sut: key_detection port map(
			clk => clk,
			rst => rst,
			KEY => KEY(3 downto 1),
			
			button_plus_pressed_once => button_plus_pressed_once,
			button_minus_pressed_once => button_minus_pressed_once,
			button_control_mode_pressed_once => button_control_mode_pressed_once,
			any_button_being_pressed => any_button_pressed
    );


	simulate: process
	begin

		rst <= '1';
		KEY <= not "000";
		wait for 65 ns;
		rst <= '0';
		wait for 40 ns;
		KEY <= not "100";  -- button ctrl
		wait for 40 ns;
		KEY <= not "010";  -- button minus
		wait for 40 ns;
		KEY <= not "001";  -- button plus
		wait for 40 ns;
		KEY <= not "011";
		wait for 40 ns;
		KEY <= not "101";
		wait for 40 ns;
		KEY <= not "110";
		wait for 40 ns;
		KEY <= not "111";
		wait for 40 ns;
		KEY <= not "000";
		wait for 40 ns;
		
		KEY <= not "001";  -- button plus
		wait for 700 ms;

		KEY <= not "010";  -- button minus
		wait for 700 ms;

		KEY <= not "100";  -- button ctrl
		wait for 700 ms;
		
		KEY <= not "111";  -- all buttons
		wait for 700 ms;

		KEY <= not "000";  -- no buttons
		wait;
	end process;
	
end architecture RTL;
