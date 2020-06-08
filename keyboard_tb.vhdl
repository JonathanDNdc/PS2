library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;


entity keyboard_tb is
    constant period     : time := 40 ns ; -- Señal de reloj de 25MHz
    constant bit_period : time := 60 us ; -- Keyboard clock ~ 16.7 Khz max
end entity;

architecture arch of keyboard_tb is
    component keyboard is
        port(
            kbd_clk, kbd_data, clk : in  std_logic;
            reset, enable          : in  std_logic;
            scan_code              : out std_logic_vector(7 downto 0);
            scan_ready             : out std_logic;
            parity_err             : out std_logic
        );
    end component;

    signal clk        : std_logic := '0';
    signal reset      : std_logic;
    signal kbd_clk    : std_logic := '1';
    signal kbd_data   : std_logic := 'H';
    signal enable     : std_logic := '0';
    signal scan_ready : std_logic;
    signal scan_code  : std_logic_vector(7 downto 0);
    signal parity_err : std_logic;

    type code_parity is record
        code    : std_logic_vector(7 downto 0);
        p_error : std_logic;
    end record;

    type codes_types is array (natural range <>) of code_parity;
    constant codes : codes_types := (
        (x"00", '0'), (x"01", '0'), (x"02", '0'), (x"03", '0'),
        (x"04", '1'), (x"05", '0'), (x"06", '0'), (x"07", '0'),
        (x"D3", '0'), (x"D5", '0'), (x"D6", '1'), (x"FF", '0')
        );

    function Even (V : std_logic_vector) return std_logic is
        variable p       : std_logic := '0';
    begin
        for i in V'range loop
            p := p xor V(i);
        end loop;
        return p;
    end function;

begin

        UUT : keyboard port map (kbd_clk, kbd_data, clk, reset, enable, scan_code, scan_ready, parity_err);

    -- Señal de reloj del sistema
    clk   <= not clk after (period / 2);
    reset <= '1', '0' after period;

    process
        procedure send_code(
                sc : std_logic_vector(7 downto 0);
                sp : std_logic
            ) is
        begin
            kbd_clk  <= 'H';
            kbd_data <= 'H';

            wait for (bit_period/2);
            kbd_data <= '0'; -- Start bit
            wait for (bit_period/2);
            kbd_clk <= '0';
            wait for (bit_period/2);
            kbd_clk <= '1';
            for i in 0 to 7 loop
                kbd_data <= sc(i);
                wait for (bit_period/2);
                kbd_clk <= '0';
                wait for (bit_period/2);
                kbd_clk <= '1';
            end loop;
            -- bit de paridad
            kbd_data <= sp xor not Even(sc);
            wait for (bit_period/2);
            kbd_clk <= '0';
            wait for (bit_period/2);
            kbd_clk <= '1';
            -- stop bit
            kbd_data <= '1';
            wait for (bit_period/2);
            kbd_clk <= '0';
            wait for (bit_period/2);
            kbd_clk  <= '1';
            kbd_data <= 'H';
            wait for (bit_period * 3);
        end procedure send_code;

    begin
        wait for bit_period;
        for i in codes'range loop
            send_code(codes(i).code, codes(i).p_error);
        end loop;
        report "Fin de la simulacion" severity failure;
    end process;


    process
        variable l     : line;
        variable index : natural := 0;
    begin
        wait until scan_ready = '1';
        wait for 300* period;
        enable <= '1';
        write (l, string'("Scan code : "));
        write (l, scan_code);

        if parity_err='1' then
            write(l, string'(" Error de paridad"));
        end if;

        if (scan_code /= codes(index).code) or (parity_err /= codes(index).p_error) then
            write(l, string'(" Diferentes resultados"));
        end if;
        index := index + 1;

        writeline(output, l);
        wait for period;
        enable <= '0';
    end process;

end arch;