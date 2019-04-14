library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- Show a figure on (VGA) screen using a screen memory interface
-- X and Y are the location on the screen:
--   * currently limited to 1440x900
--   * (0,0) is LOWER left
--   * positive X  to the right, and positive Y going up
--   * value "1111111111" for Y is out of range, so effectively clears the value on screen
-- pixel value (R,G,B): (0,0,0) is black and (255,255,255) is white
--
-- This creates its own clock domain (frequency depends on VGA display clock), currently 106.47 MHz.
--
-- after reset, memory is black (all pixels have value 0)
--

-- I want to have 1440*900*3*8 bits (8 bit RGB value for each pixel) = 3,888 MB 
-- analysis goes out of memory, and max DPRAM is 64KB of 8 bit words.
-- This is especially needed for X vs Y displaying.
-- Using SDRAM (64MB) is more overhead to program it in VHDL -- skip for now.
-- So, we now use 1 Y-value per signal, so 1440 words of 10 bits, containing the Y value


entity display_via_memory is
	port(
		clk_50MHz : in std_logic;   -- clock for pixel_* input
		reset     : in std_logic;

		pixel_X :       in std_logic_vector(10 downto 0);
		pixel_Y :       in std_logic_vector(9 downto 0);
		pixel_value_R : in std_logic_vector(7 downto 0);
		pixel_value_G : in std_logic_vector(7 downto 0);
		pixel_value_B : in std_logic_vector(7 downto 0);
		pixel_valid :   in std_logic;  -- set to 1 means X,Y and pixel_value_[RGB] are valid

		/* --- VGA output --- */
		VGA_BLANK_N: 	out std_logic;
		VGA_B:   		out std_logic_vector(7 downto 0);
		VGA_CLK:		out std_logic;
		VGA_G:			out std_logic_vector(7 downto 0);
		VGA_HS:			out std_logic;
		VGA_R:			out std_logic_vector(7 downto 0);
		VGA_SYNC_N:		out std_logic;
		VGA_VS:			out std_logic
	);
end entity display_via_memory;


architecture RTL of display_via_memory is

	component XYdisplay
	port(
		clk          : in  std_logic;
		reset        : in  std_logic;
		X            : out std_logic_vector(10 downto 0);
		Y            : out std_logic_vector(9 downto 0);
		video_enable : out std_logic;
		data_R       : in  std_logic_vector(7 downto 0);
		data_G       : in  std_logic_vector(7 downto 0);
		data_B       : in  std_logic_vector(7 downto 0);
		VGA_BLANK_N  : out std_logic;
		VGA_B        : out std_logic_vector(7 downto 0);
		VGA_CLK      : out std_logic;
		VGA_G        : out std_logic_vector(7 downto 0);
		VGA_HS       : out std_logic;
		VGA_R        : out std_logic_vector(7 downto 0);
		VGA_SYNC_N   : out std_logic;
		VGA_VS       : out std_logic
	);
	end component XYdisplay;
	
	component pll_for_vga
		port (
			refclk   : in  std_logic := '0'; --  refclk.clk
			rst      : in  std_logic := '0'; --   reset.reset
			outclk_0 : out std_logic;        -- outclk0.clk
			locked   : out std_logic         --  locked.export
		);
	end component pll_for_vga;


--    type ram_one_color_type is array (0 to 1440*900-1) of std_logic_vector(7 downto 0);   -- TODO: use configuration constants for these values
    type values_of_one_signal is array (0 to 1440-1) of std_logic_vector(9 downto 0);  -- index is X, value is screen position: 899-signal/5  (signal=0..4095)
	signal video_enable : std_logic;
	
	signal vga_clk_int : std_logic;
	signal vga_clk_int_locked : std_logic;

--	signal mem_R : std_logic_vector(1440*900*8-1 downto 0);    -- should use some configuration constants for these values
--	signal mem_RGB : std_logic_vector(1440*900-1 downto 0);    -- for now, just use one bit
--	signal mem_R : std_logic_vector(1440*900-1 downto 0);
--	signal mem_G : std_logic_vector(1440*900-1 downto 0);
--	signal mem_B : std_logic_vector(1440*900-1 downto 0);

	signal signal_1_active : values_of_one_signal;
--	signal signal_2_active : values_of_one_signal;

--	shared variable mem_R : ram_one_color_type;
--	shared variable mem_G : ram_one_color_type;
--	shared variable mem_B : ram_one_color_type;

	signal X : std_logic_vector(10 downto 0);
-- kanweg	signal prev_X_lsb : std_logic;
	signal Y : std_logic_vector(9 downto 0);

    signal signal_1_matches_XY : std_logic;
    signal axis_on_screen : std_logic;
    
    signal value_to_write_pixel_X : std_logic_vector(10 downto 0);
    signal value_to_write_pixel_Y : std_logic_vector(9 downto 0);
    signal value_to_write_active : std_logic;
	
begin
	vga_pll : pll_for_vga port map( refclk => clk_50MHz, rst => reset, 
	                                outclk_0 => vga_clk_int, locked => vga_clk_int_locked );

	-- provide data_[RGB] asynchronous for given X,Y - should be ready within a clock of the vga_clk_int
	-- when the data happens to change just at that moment, data may not be valid, but it will be valid at the next VGA screen redaw
	-- to fix this, use DPRAM with 2 different clock frequencies, which may require X and Y to be present a bit sooner, and extra latching
	-- or make DPRAM work @VGA frequency with handshaking from the 50 MHz side or ... .

	
	calc_signal_1: process(X,Y, signal_1_active)
	begin
		if (signal_1_active(to_integer(unsigned(X))) = Y) then
			signal_1_matches_XY <= '1';
		else
			signal_1_matches_XY <= '0';
		end if;
	end process;
	
	calc_axis_on_screen: process(X, Y)
	begin
		axis_on_screen <= '0';
		if (to_integer(unsigned(X)) rem 100 = 0) and ((Y(1 downto 0) AND 2b"11") = 2b"00") then  -- width starts at 0
			axis_on_screen <= '1';
		end if;
		if (to_integer(unsigned(Y)) rem 100 = 99) and ((X(1 downto 0) AND 2b"11") = 2b"00") then  -- height 899 at bottom of screen must be an axis
			axis_on_screen <= '1';
		end if;
	end process;
	
	
	
	display : XYdisplay port map( clk => vga_clk_int, reset => (reset and vga_clk_int_locked),
		 						  X => X, Y => Y, video_enable => video_enable,
--		                          data_R => mem_R( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) + 7 downto 
--		                          	               (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440)             ),
--		                          data_R => mem_R( to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440),
--                                  data_R => (others => mem_RGB( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) ) ),
                                  data_R => (others => signal_1_matches_XY),
                                  data_G => (others => (signal_1_matches_XY OR axis_on_screen)),
                                  data_B => (others => signal_1_matches_XY),

/*
		                          data_G => mem_G( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) + 7 downto 
		                          	               (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440)             ),
		                          data_B => mem_B( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) + 7 downto 
		                          	               (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440)             ),
*/
		                          VGA_BLANK_N => VGA_BLANK_N, VGA_SYNC_N => VGA_SYNC_N,
		                          VGA_HS => VGA_HS, VGA_VS => VGA_VS,
		                          VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B,
		                          VGA_CLK => VGA_CLK );

    write_mem: process( clk_50MHz ) is  -- note that writing memory is done with 50 MHz clock in control
    	constant black : std_logic_vector(7 downto 0) := "00000000";
    begin
    	if rising_edge( clk_50MHz ) then
    		if reset then
--    			for i in 0 to 1440*900-1 loop
--    				mem_R(i) <= black;
--    				mem_R(i*8+7 downto i*8) <= black;
--                    mem_RGB( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) ) <= '0';
--    			end loop;
/*    			for i in 0 to 1440*900-1 loop
    				mem_R(i) <= black;
    				mem_R(i*8+7 downto i*8) <= black;
                    mem_RGB( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) ) <= '0';
    			end loop;
*/
    			for i in 0 to 1440-1 loop
    				signal_1_active(i) <= "1111111111";   -- 1023 never matches Y value (max 900), so not displayed 
    			end loop;
--kanweg    			prev_X_lsb <= '0';

				value_to_write_active <= '0';
    		else
    			value_to_write_active <= '0';
    			if value_to_write_active then
    				signal_1_active(to_integer(unsigned(value_to_write_pixel_X))) <= std_logic_vector(to_unsigned(899-to_integer(unsigned(value_to_write_pixel_Y)),10));
--works	    			signal_1_active(to_integer(unsigned(pixel_X))) <= pixel_Y;
--  	  		    mem_R( to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440) <= pixel_value_R;
/*    			    mem_R( to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440*8 + 7 downto
    			    	   to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440*8            ) <= pixel_value_R;
    		    	mem_G( to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440*8 + 7 downto
    		    	   to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440*8            ) <= pixel_value_G;
   	 			    mem_B( to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440*8 + 7 downto
    			    	   to_integer(unsigned(pixel_X)) + to_integer(unsigned(pixel_Y))*1440*8            ) <= pixel_value_B;
*/
--	        	    mem_RGB( (to_integer(unsigned(X)) + to_integer(unsigned(Y))*1440) ) <= pixel_value_R(0);

-- clear already done at oscilloscope level
--				elsif (prev_X_lsb /= pixel_X(0)) then
--					-- clear 100 pixels ahead of current
--					prev_X_lsb <= pixel_X(0);
--					signal_1_active( (to_integer(unsigned(pixel_X))+100) mod 1440) <= 10b"1111111111";
				end if;

				if pixel_valid then  -- latch a copy to prevent timing issues
					value_to_write_pixel_X <= pixel_X;
    				value_to_write_pixel_Y <= pixel_y;
    				value_to_write_active <= '1';
    			end if;

    		end if;
   		end if;
    end process;


end architecture RTL;
