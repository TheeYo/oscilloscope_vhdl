library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A local PLL is used for resolution 1440x900 @ 106.47 MHz

entity XYdisplay is
	port(
		clk : in std_logic;  -- 106.47 MHz clock input
		reset : in std_logic;
		
		/* XY for NEXT pixel to client */
		X: out std_logic_vector(10 downto 0);
		Y: out std_logic_vector(9 downto 0);
		video_enable: out std_logic;  -- this next XY will actually be displayed
		
		/* RGB data from client at given XY (don't care when video_enable=0)*/
		data_R:	in std_logic_vector(7 downto 0);
		data_G:	in std_logic_vector(7 downto 0);
		data_B:	in std_logic_vector(7 downto 0);
		
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
end entity XYdisplay;


architecture RTL of XYdisplay is


-- For 1440x900 display @106.47 MHz, tested OK
-- http://www.tinyvga.com/vga-timing/1440x900@60Hz
	constant HOR_IMAGE : integer := 1440;
	constant HOR_FP : integer := 80;
	constant HOR_SYNC_PULSE : integer := 152;
	constant HOR_BP : integer := 232;
	constant HOR_SYNC_SIGNAL : std_logic := '0';   -- 0 for negative active

	constant VER_IMAGE : integer := 900;
	constant VER_FP : integer := 1;
	constant VER_SYNC_PULSE : integer := 3;
	constant VER_BP : integer := 28;


-- For 1280x1024 display (timings from DE1 guide) @108 Mhz
--	constant HOR_IMAGE : integer := 1280;
--	constant HOR_FP : integer := 43;
--	constant HOR_SYNC_PULSE : integer := 108;
--	constant HOR_BP : integer := 248;
--	constant HOR_SYNC_SIGNAL : std_logic := '1';
--
--	constant VER_IMAGE : integer := 1024;
--	constant VER_FP : integer := 1;
--	constant VER_SYNC_PULSE : integer := 3;
--	constant VER_BP : integer := 38;

	
-- For 800x600 display @50 Mhz, tested OK
--	constant HOR_IMAGE : integer := 800;
--	constant HOR_FP : integer := 56;
--	constant HOR_SYNC_PULSE : integer := 120;
--	constant HOR_BP : integer := 64;
--	constant HOR_SYNC_SIGNAL : std_logic := '1';
--
--	constant VER_IMAGE : integer := 600;
--	constant VER_FP : integer := 37;
--	constant VER_SYNC_PULSE : integer := 6;
--	constant VER_BP : integer := 23;


--component XYdisplay
--	port(
--		clk          : in  std_logic;
--		reset        : in  std_logic;
--		X            : out std_logic_vector(9 downto 0);
--		Y            : out std_logic_vector(9 downto 0);
--		video_enable : out std_logic;
--		data_R       : in  std_logic_vector(7 downto 0);
--		data_G       : in  std_logic_vector(7 downto 0);
--		data_B       : in  std_logic_vector(7 downto 0);
--		VGA_BLANK_N  : out std_logic;
--		VGA_B        : out std_logic_vector(7 downto 0);
--		VGA_CLK      : out std_logic;
--		VGA_G        : out std_logic_vector(7 downto 0);
--		VGA_HS       : out std_logic;
--		VGA_R        : out std_logic_vector(7 downto 0);
--		VGA_SYNC_N   : out std_logic;
--		VGA_VS       : out std_logic
--	);
--end component XYdisplay;

begin

	VGA_CLK <= clk;
	VGA_BLANK_N <= '1';  -- https://electronics.stackexchange.com/questions/293675/debugging-fpga-vga-connection
	VGA_SYNC_N <= '0';   --  If sync information is not required on the green channel, the SYNC_N input should be tied to Logic 0.

	vga : process (clk) is
		-- where we are currently diplaying (order: image, fp, sync, bp)
		variable hpos : integer range 0 to  HOR_IMAGE + HOR_FP + HOR_SYNC_PULSE + HOR_BP - 1;
		variable vpos : integer range 0 to  VER_IMAGE + VER_FP + VER_SYNC_PULSE + VER_BP - 1;
		
	begin
		if rising_edge(clk) then
			-- default values to disable, may be overruled
			video_enable <= '0';
			VGA_VS <= '0';
			VGA_HS <= not HOR_SYNC_SIGNAL;
			video_enable <= '0';
			VGA_R <= "00000000";
			VGA_G <= "00000000";
			VGA_B <= "00000000";
			
			if reset = '1' then
				hpos := HOR_IMAGE;
				vpos := VER_IMAGE;
				X <= 11b"0";
				Y <= 10b"0";
			else
				-- order: sync, bp, active, fp
				if vpos < VER_IMAGE then
					Y <= std_logic_vector(to_unsigned(vpos, 10));
					if hpos < HOR_IMAGE - 1 then
						X <= std_logic_vector(to_unsigned(hpos+1, 11));
						video_enable <= '1';
						VGA_R <= data_R;
						VGA_G <= data_G;
						VGA_B <= data_B;
					elsif hpos < HOR_IMAGE then
						X <= 11b"0";  -- This hpos may be displayed, but next X will not be active
						VGA_R <= data_R;
						VGA_G <= data_G;
						VGA_B <= data_B;
					elsif hpos < HOR_IMAGE + HOR_FP then
						X <= 11b"0";
					elsif hpos < HOR_IMAGE + HOR_FP + HOR_SYNC_PULSE then
						X <= 11b"0";
						VGA_HS <= HOR_SYNC_SIGNAL;   -- horizontal sync active
					elsif hpos < HOR_IMAGE + HOR_FP + HOR_SYNC_PULSE + HOR_BP - 1 then
						X <= 11b"0";
					elsif hpos < HOR_IMAGE + HOR_FP + HOR_SYNC_PULSE + HOR_BP then
						X <= 11b"0";
					end if;
				else
					video_enable <= '0';
					X <= 11b"0";
					Y <= 10b"0";
					if (vpos >= VER_IMAGE + VER_FP) and (vpos < VER_IMAGE + VER_FP + VER_SYNC_PULSE) then
						VGA_VS <= '1';     -- vertical sync active
					end if;
					if (hpos >= HOR_IMAGE + HOR_FP) and (hpos < HOR_IMAGE + HOR_FP + HOR_SYNC_PULSE) then
						VGA_HS <= HOR_SYNC_SIGNAL;   -- horizontal sync active
					end if;
				end if;

				-- increment counters				
				if hpos < HOR_IMAGE + HOR_FP + HOR_SYNC_PULSE + HOR_BP - 1 then
					hpos := hpos + 1;
				else
				   -- going to next line on screen
					hpos := 0;
					if vpos < VER_IMAGE + VER_FP + VER_SYNC_PULSE + VER_BP - 1 then
						vpos := vpos + 1;
					else
						vpos := 0;
						video_enable <= '1'; -- very last (hpos, vpos), so next pixel will be (0,0)
					end if;
					if vpos < VER_IMAGE then
						Y <= std_logic_vector(to_unsigned(vpos, 10));
					else
						Y <= 10b"0";
					end if;
				end if;
			end if;   -- reset = '1'
			
			if (video_enable = '0') then
				assert X = 11b"0" report "when video is disabled, X should be 0" severity ERROR;
			end if;
		end if;   -- rising clk
	end process vga;


--  http://www.tinyvga.com/vga-timing

/*
 * VESA Signal 800 x 600 @ 72 Hz timing
 * 
 * General timing
 * Screen refresh rate 72 Hz
 * Vertical refresh 48.076923076923 kHz
 * Pixel freq. 50.0 MHz
 * 
 * Horizontal timing (line)
 * Polarity of horizontal sync pulse is positive.
 * Scanline part	Pixels	Time [us]
 * Visible area		800		16
 * Front porch		56		1.12
 * Sync pulse		120		2.4
 * Back porch		64		1.28
 * Whole line		1040	20.8
 * 
 * Vertical timing (frame)
 * Polarity of vertical sync pulse is positive.
 * Frame part		Lines	Time [ms]
 * Visible area		600		12.48
 * Front porch		37		0.7696
 * Sync pulse		6		0.1248
 * Back porch		23		0.4784
 * Whole frame		666		13.8528
 */

end architecture RTL;
