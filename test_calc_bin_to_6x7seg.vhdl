library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test_calc_bin_to_6x7seg is
end entity test_calc_bin_to_6x7seg;

architecture test of test_calc_bin_to_6x7seg is
	
	component calc_bin_to_6x7seg port(
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
	end component calc_bin_to_6x7seg;

	signal HEX0: std_logic_vector(6 downto 0);
	signal HEX1: std_logic_vector(6 downto 0);
	signal HEX2: std_logic_vector(6 downto 0);
	signal HEX3: std_logic_vector(6 downto 0);
	signal HEX4: std_logic_vector(6 downto 0);
	signal HEX5: std_logic_vector(6 downto 0);
	signal binaryNumber : std_logic_vector(19 downto 0);
	
begin

	sut :  calc_bin_to_6x7seg port map( binaryNumber, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0 );

	simulate: process
	begin
		
		binaryNumber <= std_logic_vector(to_unsigned(999999, binaryNumber'length));
		wait for 100 ns;
		assert HEX0=not "1101111" report "HEX0 nok for 999999" severity error;
		assert HEX1=not "1101111" report "HEX1 nok for 999999" severity error;
		assert HEX2=not "1101111" report "HEX2 nok for 999999" severity error;
		assert HEX3=not "1101111" report "HEX3 nok for 999999" severity error;
		assert HEX4=not "1101111" report "HEX4 nok for 999999" severity error;
		assert HEX5=not "1101111" report "HEX5 nok for 999999" severity error;
		
		binaryNumber <= std_logic_vector(to_unsigned(0, binaryNumber'length));
		wait for 100 ns;
		assert HEX0=not "0111111" report "HEX0 nok for 0" severity error;
		assert HEX1=not "0111111" report "HEX1 nok for 0" severity error;
		assert HEX2=not "0111111" report "HEX2 nok for 0" severity error;
		assert HEX3=not "0111111" report "HEX3 nok for 0" severity error;
		assert HEX4=not "0111111" report "HEX4 nok for 0" severity error;
		assert HEX5=not "0111111" report "HEX5 nok for 0" severity error;

		
	end process simulate;


end architecture test;
