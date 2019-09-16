----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:46:42 06/30/2019 
-- Design Name: 
-- Module Name:    top - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top is
    Port ( CLK : in  STD_LOGIC;
           LED : inout  STD_LOGIC_VECTOR (4 downto 0);
           SW1_CTL : inout  STD_LOGIC_VECTOR (2 downto 0);
           SW2_CTL : inout  STD_LOGIC_VECTOR (2 downto 0);
           MOD_EN : inout  STD_LOGIC;
           DORI : out  STD_LOGIC;
           SELIQ : out  STD_LOGIC;
           I : out  STD_LOGIC_VECTOR (11 downto 0);
           Q : out  STD_LOGIC_VECTOR (11 downto 0);
           CLK_DAC_P : out  STD_LOGIC;
           CLK_DAC_N : out  STD_LOGIC;
           REF_CLK : in  STD_LOGIC;
           SPI_INT_SCK : in  STD_LOGIC;
           SPI_INT_CS : in  STD_LOGIC;
           SPI_INT_MOSI : in  STD_LOGIC;
           SPI_INT_MISO : out  STD_LOGIC;
           SPI_EXT_SCK : in  STD_LOGIC;
           SPI_EXT_CS : in  STD_LOGIC;
           SPI_EXT_MOSI : in  STD_LOGIC;
           SPI_EXT_MISO : out  STD_LOGIC);
end top;

--FPGA register map:
--0x0000: GPIO register:
--	[0-2]: SW1_CTL
--	[4-6]: SW2_CTL
--	[7]: Modulator enabled
--	[8-12]: LEDs
--0x0001: reserved
--0x0002: DAC I direct:
--	[0-11]: I DAC value if modulation disabled
--0x0003: DAC Q direct:
--	[0-11]: Q DAC value if modulation disabled
--0x0004: Modulation source phase increment
--0x0005: Modulation setting1
--0x0007: Modulation CTRL:
--	[0-7]: Modulation type
--	[11-8]: Source type

architecture Behavioral of top is
	component MainPLL
	port
	 (-- Clock in ports
	  CLK_IN1           : in     std_logic;
	  -- Clock out ports
	  CLK_OUT1          : out    std_logic;
	  -- Status and control signals
	  LOCKED            : out    std_logic
	 );
	end component;
	COMPONENT spi_slave
	generic (W : integer);
	PORT(
		SPI_CLK : IN std_logic;
		MOSI : IN std_logic;
		CS : IN std_logic;
		BUF_IN : IN std_logic_vector (W-1 downto 0);
		CLK : IN std_logic;          
		MISO : OUT std_logic;
		BUF_OUT : OUT std_logic_vector (W-1 downto 0);
		COMPLETE : OUT std_logic
	);
	END COMPONENT;
	
	COMPONENT Modulation
	PORT(
		CLK : IN std_logic;
		RESET : IN std_logic;
		SOURCE : IN std_logic_vector(11 downto 0);
		NEW_SAMPLE : IN std_logic;
		MODTYPE : IN std_logic_vector(7 downto 0);
		SETTING1 : IN std_logic_vector(15 downto 0);
		SETTING2 : IN std_logic_vector(15 downto 0);          
		DAC_I : OUT std_logic_vector(11 downto 0);
		DAC_Q : OUT std_logic_vector(11 downto 0);
		
		I_Q_Address : in STD_LOGIC_VECTOR (8 downto 0);
		I_Q_Data : in STD_LOGIC_VECTOR (11 downto 0);
		I_Q_Write : in STD_LOGIC_VECTOR (0 downto 0)
		);
	END COMPONENT;
	
	COMPONENT ModSource
	GENERIC(
		STREAM_DEPTH : integer
	);
	PORT(
		CLK : IN std_logic;
		RESET : IN std_logic;
		SRCTYPE : IN std_logic_vector(3 downto 0);
		PINC : IN std_logic_vector(15 downto 0);          
		RESULT : OUT std_logic_vector(11 downto 0);
		NEW_SAMPLE : OUT std_logic;
		SPI_SCK : in STD_LOGIC;
		SPI_CS : in STD_LOGIC;
		SPI_MOSI : in STD_LOGIC;
		SPI_MISO : out STD_LOGIC
		);
	END COMPONENT;
	
	signal CLK100 : std_logic;
	signal CLK100_INV : std_logic;
	signal DAC_CLK : std_logic;
	
	signal first : std_logic := '0';
	signal write_not_read : std_logic := '0';
	signal mem_address : std_logic_vector(14 downto 0) := (others => '0');
	
	signal spi_int_out : std_logic_vector(15 downto 0);
	signal spi_int_in : std_logic_vector(15 downto 0);
	signal spi_int_complete : std_logic := '0';
	
	-- modulation settings
	signal mod_type : std_logic_vector(7 downto 0);
	signal mod_setting1 : std_logic_vector(15 downto 0);
	-- modulation source settings
	signal mod_src_pinc : std_logic_vector(15 downto 0);
	signal mod_src_type : std_logic_vector(3 downto 0);
	signal mod_src_value : std_logic_vector(11 downto 0);
	signal mod_src_new : std_logic;

begin
your_instance_name : MainPLL
  port map
   (-- Clock in ports
    CLK_IN1 => CLK,
    -- Clock out ports
    CLK_OUT1 => CLK100,
    -- Status and control signals
    LOCKED => open);
	 
	 CLK100_INV <= not CLK100;
	 
	 ODDR2_inst : ODDR2
   generic map(
      DDR_ALIGNMENT => "NONE", -- Sets output alignment to "NONE", "C0", "C1" 
      INIT => '0', -- Sets initial state of the Q output to '0' or '1'
      SRTYPE => "SYNC") -- Specifies "SYNC" or "ASYNC" set/reset
   port map (
      Q => DAC_CLK, -- 1-bit output data
      C0 => CLK100, -- 1-bit clock input
      C1 => CLK100_INV, -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D0 => '0',   -- 1-bit data input (associated with C0)
      D1 => '1',   -- 1-bit data input (associated with C1)
      R => '0',    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );
	
	 OBUFDS_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT")
   port map (
      O => CLK_DAC_P,     -- Diff_p output (connect directly to top-level port)
      OB => CLK_DAC_N,   -- Diff_n output (connect directly to top-level port)
      I => DAC_CLK      -- Buffer input 
   );
	
	SPI_interface : spi_slave 
	GENERIC MAP(W => 16)
	PORT MAP(
		SPI_CLK => SPI_INT_SCK,
		MISO => SPI_INT_MISO,
		MOSI => SPI_INT_MOSI,
		CS => SPI_INT_CS,
		BUF_OUT => spi_int_out,
		BUF_IN => spi_int_in,
		CLK => CLK100,
		COMPLETE => spi_int_complete
	);
	
	Source: ModSource
	GENERIC MAP (STREAM_DEPTH => 14)
	PORT MAP(
		CLK => CLK100,
		RESET => '0',
		SRCTYPE => mod_src_type,
		PINC => mod_src_pinc,
		RESULT => mod_src_value,
		NEW_SAMPLE => mod_src_new,
		SPI_SCK => SPI_EXT_SCK,
		SPI_CS => SPI_EXT_CS,
		SPI_MISO => SPI_EXT_MISO,
		SPI_MOSI => SPI_EXT_MOSI
	);
	
	Modulator: Modulation PORT MAP(
		CLK => CLK100,
		RESET => '0',
		DAC_I => I,
		DAC_Q => Q,
		SOURCE => mod_src_value,
		NEW_SAMPLE => mod_src_new,
		MODTYPE => mod_type,
		SETTING1 => mod_setting1,
		SETTING2 => (others => '0'),
		I_Q_Address => (others => '0'),
		I_Q_Data => (others => '0'),
		I_Q_Write => (others => '0')
	);
	
	DORI <= '1';
	SELIQ <= '0';
	--SPI_EXT_MISO <= 'Z';
	process(CLK100)
	begin
		if rising_edge(CLK100) then
			if SPI_INT_CS = '1' then
				first <= '1';
				mem_address <= "000000000000000";
			else
				if spi_int_complete = '1' then
					if first = '1' then
						write_not_read <= spi_int_out(15);
						mem_address <= spi_int_out(14 downto 0);
						first <= '0';
					else
						if write_not_read = '1' then
							case mem_address is
								when "000000000000000" =>
									-- write to GPIO register
									SW1_CTL <= spi_int_out(2 downto 0);
									SW2_CTL <= spi_int_out(6 downto 4);
									MOD_EN <= spi_int_out(7);
									SW1_CTL <= spi_int_out(2 downto 0);
									LED <= spi_int_out(12 downto 8);
								-- modulation source phase increment
								when "000000000000100" =>
									mod_src_pinc <= spi_int_out;
								-- modulation setting1
								when "000000000000101" =>
									mod_setting1 <= spi_int_out;
								-- modulation and source types
								when "000000000000111" =>
									mod_type <= spi_int_out(7 downto 0);
									mod_src_type <= spi_int_out(11 downto 8);
								when others =>
							end case;
						end if;
						-- increment address
						mem_address <= std_logic_vector(unsigned(mem_address) + 1);
					end if;
				end if;
			end if;
			-- assign spi_in dependent on mem_address
	--			spi_in <= '0' & mem_address;
			case mem_address is
				when "000000000000000" =>
					spi_int_in <= "000" & LED(4 downto 0) & MOD_EN & SW2_CTL(2 downto 0) & "0" & SW1_CTL(2 downto 0);
--				when "000000000000010" =>
--					spi_int_in <= "0000" & I_direct;
--				when "000000000000011" =>
--					spi_int_in <= "0000" & Q_direct;
				when "000000000000100" =>
					spi_int_in <= mod_src_pinc;
				when "000000000000101" =>
					spi_int_in <= mod_setting1;
				when "000000000000111" =>
					spi_int_in <= "0000" & mod_src_type & mod_type;
				when others => spi_int_in <= (others => '0');
			end case;
		end if;
	end process;

end Behavioral;

