-- Contents of the simulation memory, shared by the testbench and the memory model.
-- The testbench writes a program into sim_mem; external_mem (sim version) reads it.

library ieee;
use ieee.std_logic_1164.all;

package mem_sim_pkg is
  -- 64 words of 8 bits, like the CPU's memory
  type mem_t is array (0 to 63) of std_logic_vector(7 downto 0);

  -- The memory contents. Only the testbench writes this signal.
  signal sim_mem : mem_t := (others => x"00");
end package;