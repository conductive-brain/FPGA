-- Simulation model of the CPU memory. Replaces the Intel ROM (external_mem_altera.vhd)
-- in the GHDL tests. Same entity name, same ports, same timing as altsyncram with an
-- unregistered output: the address is stored on the rising clock edge, and q shows
-- the byte at the stored address right after.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_sim_pkg.all;

entity external_mem is
  port (
    address : in  std_logic_vector(5 downto 0);
    clock   : in  std_logic := '1';
    q       : out std_logic_vector(7 downto 0)
  );
end entity;

architecture sim of external_mem is
  signal addr_reg : std_logic_vector(5 downto 0) := (others => '0');
begin
  -- Store the address on each rising clock edge
  process (clock)
  begin
    if rising_edge(clock) then
      addr_reg <= address;
    end if;
  end process;

  -- Output the byte at the stored address
  q <= sim_mem(to_integer(unsigned(addr_reg)));
end architecture;