-- Wrapper around the microprogrammed CPU, for the tests.
-- The tests connect to entity cpu_dut and never to a CPU directly. This file
-- connects the microprogrammed CPU and brings its control unit state out on
-- the cu_state pin. tb/cpu_dut_hw.vhd does the same for the hardwired CPU.
-- Only one of the two is compiled in each test run.

library ieee;
use ieee.std_logic_1164.all;

entity cpu_dut is
  port (
    ARout, PCout          : out std_logic_vector(5 downto 0);
    DRout, ACout, dataBus : out std_logic_vector(7 downto 0);
    IRout                 : out std_logic_vector(1 downto 0);
    mOP                   : out std_logic_vector(10 downto 0);
    clock, reset          : in  std_logic;
    cu_state              : out std_logic_vector(3 downto 0)  -- 0000 = FETCH1
  );
end entity;

architecture micro of cpu_dut is
begin
  cpu : entity work.vs_cpu
    port map (
      ARout   => ARout,
      PCout   => PCout,
      DRout   => DRout,
      ACout   => ACout,
      IRout   => IRout,
      dataBus => dataBus,
      clock   => clock,
      reset   => reset,
      mOP     => mOP
    );

  -- The state of the microprogrammed control unit is the address stored in
  -- the microcode ROM: instance cpu, then control_unit, then memory (the ROM).
  cu_state <= <<signal cpu.control_unit.memory.addr_reg : std_logic_vector(3 downto 0)>>;
end architecture;