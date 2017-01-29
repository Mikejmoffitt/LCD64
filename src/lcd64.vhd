library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity lcd64 is
port (
	
	n64_data: in std_logic_vector(6 downto 0);
	n64_clock: in std_logic;
	n64_dsync_n: in std_logic;
	
	lcd_red: out std_logic_vector(7 downto 0);
	lcd_green: out std_logic_vector(7 downto 0);
	lcd_blue: out std_logic_vector(7 downto 0);
	
	lcd_hs: out std_logic;
	lcd_vs: out std_logic;
	lcd_clk: out std_logic;
	
	lcd_tb: out std_logic;
	lcd_rl: out std_logic;
	lcd_en: out std_logic;
	
	sw_rl: in std_logic;
	sw_tb: in std_logic;
	
	lcd_reset: out std_logic
);
end lcd64;

architecture behavioral of lcd64 is

signal n64_red: std_logic_vector(6 downto 0);
signal n64_green: std_logic_vector(6 downto 0);
signal n64_blue: std_logic_vector(6 downto 0);

signal n64_csync: std_logic;
signal n64_vsync: std_logic;
signal n64_clamp: std_logic;
signal n64_hsync: std_logic;

signal hsync_prev: std_logic;
signal n64_clock_count: std_logic_vector(1 downto 0);

signal clock_count: std_logic_vector(4 downto 0) := "00000";

signal reset_counter: std_logic_vector(4 downto 0) := "00000";

signal cap_phase: std_logic := '0';

signal hsync_pulse_delay: std_logic_vector(15 downto 0) := X"0000";

constant PULSE_ACTIVE: integer := 96;
constant PULSE_LEN: std_logic_vector(15 downto 0) := X"0C40";

signal gamma_red: std_logic_vector(7 downto 0);
signal gamma_green: std_logic_vector(7 downto 0);
signal gamma_blue: std_logic_vector(7 downto 0);

signal hsync_delayed: std_logic;

begin

	gamma_red_adj: entity work.gamma_curver(behavioral)
		port map (n64_red & '0', gamma_red);
	gamma_green_adj: entity work.gamma_curver(behavioral)
		port map (n64_green & '0', gamma_green);
	gamma_blue_adj: entity work.gamma_curver(behavioral)
		port map (n64_blue & '0', gamma_blue);

	pixel_processor: entity work.n64_pixel(behavioral) 
		port map (n64_data, n64_clock, n64_dsync_n,
		          n64_red, n64_green, n64_blue,
		          n64_csync, n64_hsync, n64_clamp, n64_vsync,
		          n64_clock_count, '1', '1');
				  
	hsync_edge: process(n64_clock)
	begin
		if (rising_edge(n64_clock)) then
			hsync_prev <= n64_hsync;
		end if;
	end process;
	
	hsync_delay: process(n64_clock)
	begin
		if (rising_edge(n64_clock)) then
			-- Edge detection
			if (n64_hsync = '0' and hsync_prev = '1') then
				hsync_pulse_delay <= PULSE_LEN;
			elsif (hsync_pulse_delay /= X"0000") then
				hsync_pulse_delay <= hsync_pulse_delay - 1;
			end if;
		end if;
	end process;
	
	generated_hsync_delay: process(n64_clock)
	begin
		if (rising_edge(n64_clock)) then
			if (hsync_pulse_delay /= X"0000" and hsync_pulse_delay < PULSE_ACTIVE) then
				hsync_delayed <= '0';
			else
				hsync_delayed <= '1';
			end if;
		end if;
	end process;
	
	phase_osc: process(n64_clock)
	begin
		if (rising_edge(n64_clock)) then
			if (n64_hsync = '1' and hsync_prev = '0') then
				clock_count <= "00000";
			else
				clock_count <= clock_count + 1;
			end if;
		end if;
	end process;
	
	reset_proc: process(n64_clock)
	begin
		if (rising_edge(n64_clock)) then
			if (reset_counter /= "11111") then
				reset_counter <= reset_counter + 1;
				lcd_reset <= '0';
			else
				lcd_reset <= '1';
			end if;
		end if;
	end process;
	
	lcd_outputs: process(n64_clock)
	begin
		if (rising_edge(n64_clock)) then
			lcd_red <= gamma_red;
			lcd_green <= gamma_green;
			lcd_blue <= gamma_blue;
			lcd_hs <= hsync_delayed;
			lcd_vs <= n64_vsync;
			lcd_clk <= sw_rl xor clock_count(2);
			
			lcd_tb <= sw_tb;
			lcd_rl <= sw_rl;
			lcd_en <= n64_clamp;
		end if;
	end process;
end architecture;