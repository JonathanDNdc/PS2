library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity keyboard is
    port(
        kbd_clk, kbd_data, clk : in  std_logic;
        reset, enable          : in  std_logic;
        scan_code              : out std_logic_vector(7 downto 0);
        scan_ready             : out std_logic;
        parity_err                 : out std_logic
    );
end entity;

architecture arch of keyboard is

    signal filter           : std_logic_vector(7 downto 0) := "00000000";
    signal kbd_clk_filtered : std_logic                    := '0';
    signal ready_set        : std_logic                    := '0';
    signal incount          : unsigned(3 downto 0)         := "0000";
    signal shiftin          : std_logic_vector(8 downto 0) := "000000000";
    signal parity_err_i          : std_logic                    := '0';
    type statetype is (IDLE, READING);
    signal state : statetype := IDLE;

begin

    -- Filtro del reloj del teclado
    clk_filter : process (clk)
    begin
        if rising_edge(clk) then
            filter <= kbd_clk&filter(7 downto 1);
            if filter = x"FF" then
                kbd_clk_filtered <= '1';
            elsif filter = x"00" then
                kbd_clk_filtered <= '0';
            end if;
        end if;
    end process;

    -- FSM de lectura serial
    process (kbd_clk_filtered, reset)
    begin
        if reset='1' then
            state   <= IDLE;
            incount <= "0000";
        elsif falling_edge(kbd_clk_filtered) then
            case state is
                when IDLE =>
                    parity_err_i <= '0';
                    if kbd_data='0' then
                        state <= READING;
                    end if;
                when READING =>
                    if incount < "1001" then
                        incount   <= incount + 1;
                        shiftin   <= kbd_data&shiftin(8 downto 1);
                        ready_set <= '0';
                        parity_err_i   <= parity_err_i xor kbd_data;
                    else
                        scan_code <= shiftin(7 downto 0);
                        ready_set <= '1';
                        incount   <= "0000";
                        parity_err    <= not parity_err_i;
                        state     <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- scan_ready
    process (enable, ready_set)
    begin
        if enable = '1' then
            scan_ready <= '0';
        elsif ready_set'event and ready_set = '1' then
            scan_ready <= '1';
        end if;
    end process;


end arch;