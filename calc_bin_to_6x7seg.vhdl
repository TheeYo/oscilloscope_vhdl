library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calc_bin_to_6x7seg is
	port(
		binaryNumber : in std_logic_vector(19 downto 0);  -- 2^20 > 999.999 (max on 6 segments)
		HEX0: out std_logic_vector(6 downto 0);
		HEX1: out std_logic_vector(6 downto 0);
		HEX2: out std_logic_vector(6 downto 0);
		HEX3: out std_logic_vector(6 downto 0);
		HEX4: out std_logic_vector(6 downto 0);
		HEX5: out std_logic_vector(6 downto 0)
	);
end entity calc_bin_to_6x7seg;


architecture RTL of calc_bin_to_6x7seg is
	
	function map_bcd_to_7seg( bcd_val : unsigned(3 downto 0) )
	return std_logic_vector is
		variable dseg : std_logic_vector(6 downto 0);
	begin
		case bcd_val is
			when "0000" => dseg := not "0111111";  -- 0
			when "0001" => dseg := not "0000110";  -- 1
			when "0010" => dseg := not "1011011";  -- 2
			when "0011" => dseg := not "1001111";  -- 3
			when "0100" => dseg := not "1100110";  -- 4
			when "0101" => dseg := not "1101101";  -- 5
			when "0110" => dseg := not "1111101";  -- 6
			when "0111" => dseg := not "0000111";  -- 7
			when "1000" => dseg := not "1111111";  -- 8
			when "1001" => dseg := not "1101111";  -- 9
			when others => dseg := not "1111001";  -- E
		end case;
		return dseg;
	end map_bcd_to_7seg;
	
begin

	-- note: not synchronous, only depends on input signal change
    process(binaryNumber) is
	variable bcd : unsigned(4*6-1 downto 0);
	begin
		
		bcd:= 24b"0";
		for i in 0 to binaryNumber'length - 1 loop
		    
			for digit in 0 to 5 loop
				if (bcd(digit*4+3 downto digit*4) > 4) then
					bcd(digit*4+3 downto digit*4) := bcd(digit*4+3 downto digit*4) + 3;
				end if;
			end loop;
			bcd := bcd(4*6-2 downto 0) & binaryNumber(binaryNumber'length - 1 - i);
		end loop;
		
		HEX0 <= map_bcd_to_7seg(bcd(3 downto 0));
		HEX1 <= map_bcd_to_7seg(bcd(7 downto 4));
		HEX2 <= map_bcd_to_7seg(bcd(11 downto 8));
		HEX3 <= map_bcd_to_7seg(bcd(15 downto 12));
		HEX4 <= map_bcd_to_7seg(bcd(19 downto 16));
		HEX5 <= map_bcd_to_7seg(bcd(23 downto 20));

	end process;


end architecture RTL;
