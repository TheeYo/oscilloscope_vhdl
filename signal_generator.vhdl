library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_generator is
	port(
		clk : in std_logic;
		signals : out std_logic_vector(5 downto 0)
	);
end entity signal_generator;

architecture RTL of signal_generator is
	signal signal_block_1Hz : std_logic;
	signal signal_block_10Hz : std_logic;
	signal signal_block_100Hz : std_logic;
	signal signal_block_1KHz : std_logic;
	signal signal_block_10KHz : std_logic;
	signal signal_block_100KHz : std_logic;
	
	signal gen100KHz_counter : integer range 0 to 250-1;
	signal gen10KHz_counter : integer range 0 to 10-1;
	signal gen1KHz_counter : integer range 0 to 10-1;
	signal gen100Hz_counter : integer range 0 to 10-1;
	signal gen10Hz_counter : integer range 0 to 10-1;
	signal gen1Hz_counter : integer range 0 to 10-1;
begin
	signals <= signal_block_1Hz & signal_block_10Hz & signal_block_100Hz &
	           signal_block_1KHz & signal_block_10KHz & signal_block_100KHz;

	gen_signals : process(clk) is
	begin
		-- TODO make a for loop out of this
		if rising_edge(clk) then
			if gen100KHz_counter = 0 then
				gen100KHz_counter <= 250-1;
				signal_block_100KHz <= not signal_block_100KHz;
				if gen10Khz_counter = 0 then
					gen10KHz_counter <= 10-1;
					signal_block_10KHz <= not signal_block_10KHz;
					if gen1Khz_counter = 0 then
						gen1Khz_counter <= 10-1;
						signal_block_1KHz <= not signal_block_1KHz;
						if gen100hz_counter = 0 then
							gen100Hz_counter <= 10-1;
							signal_block_100Hz <= not signal_block_100Hz;
							if gen10Hz_counter = 0 then
								gen10Hz_counter <= 10-1;
								signal_block_10Hz <= not signal_block_10Hz;
								if gen1hz_counter = 0 then
									gen1Hz_counter <= 10-1;
									signal_block_1Hz <= not signal_block_1Hz;
								else
									gen1Hz_counter <= gen1Hz_counter - 1;
								end if;
							else
								gen10Hz_counter <= gen10Hz_counter - 1;
							end if;
						else
							gen100Hz_counter <= gen100Hz_counter - 1;
						end if;
					else
						gen1KHz_counter <= gen1KHz_counter - 1;
					end if;
				else
					gen10KHz_counter <= gen10KHz_counter - 1;
				end if;
			else
				gen100KHz_counter <= gen100KHz_counter -1;
			end if;
		end if;
		
	end process gen_signals;
	

end architecture RTL;
