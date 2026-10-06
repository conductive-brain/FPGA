-- Simulation model of the microcode ROM (rom_microp), for the GHDL tests.
-- Replaces the Intel ROM (src/micro/rom_microp_altera.vhd), which only Quartus
-- uses. Same ports and the same timing as altsyncram with an unregistered
-- output: the address is stored on the rising clock edge, and q shows the word
-- at the stored address. The stored address is the control unit's state.
-- The contents come from microcode.mif, the same file Quartus uses, so the
-- microcode exists in one place only. The run script copies microcode.mif into
-- the folder the simulation runs in.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity rom_microp is
  port (
    address : in  std_logic_vector(3 downto 0);
    clock   : in  std_logic := '1';
    q       : out std_logic_vector(15 downto 0)
  );
end entity;

architecture sim of rom_microp is
  type rom_t is array (0 to 15) of std_logic_vector(15 downto 0);

  -- Read a .mif file. Only the data lines contain a colon, for example
  --    8 : 0000100000011001 ; -- ADD1
  -- (address, colon, 16 binary digits). All other lines are skipped.
  impure function read_mif(file_name : string) return rom_t is
    file f            : text open read_mode is file_name;
    variable l        : line;
    variable rom      : rom_t := (others => (others => '0'));  -- unused addresses are 0, as in Quartus
    variable colon, i : natural;
    variable addr     : natural;
  begin
    while not endfile(f) loop
      readline(f, l);
      -- Find the colon
      colon := 0;
      for k in l'range loop
        if l(k) = ':' then
          colon := k;
          exit;
        end if;
      end loop;
      if colon > 0 then
        -- The address is the number before the colon
        addr := natural'value(l(l'low to colon - 1));
        -- Skip the spaces after the colon, then read 16 binary digits
        i := colon + 1;
        while l(i) = ' ' loop
          i := i + 1;
        end loop;
        for b in 15 downto 0 loop
          if l(i) = '1' then
            rom(addr)(b) := '1';
          else
            rom(addr)(b) := '0';
          end if;
          i := i + 1;
        end loop;
      end if;
    end loop;
    return rom;
  end function;

  constant MICROCODE : rom_t := read_mif("microcode.mif");

  -- No start value: the stored address is unknown until the CPU is reset
  signal addr_reg : std_logic_vector(3 downto 0);
begin
  -- Store the address on each rising clock edge
  process (clock)
  begin
    if rising_edge(clock) then
      addr_reg <= address;
    end if;
  end process;

  -- Output the word at the stored address. While the address is unknown,
  -- the output is unknown too.
  q <= MICROCODE(to_integer(unsigned(addr_reg))) when not is_x(addr_reg) else (others => 'X');
end architecture;