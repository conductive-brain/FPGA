-- Wrapper around the hardwired CPU, for the tests.
-- The tests connect to entity cpu_dut and never to a CPU directly. This file
-- connects the hardwired CPU and brings its control unit state out on the
-- cu_state pin. tb/cpu_dut_micro.vhd does the same for the microprogrammed CPU.
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

architecture hw of cpu_dut is
begin
  cpu : entity work.vs_cpu_hw
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

  -- The state counter inside the control unit. The path starts at this
  -- architecture: instance cpu, then control_unit, then the signal.
  cu_state <= <<signal cpu.control_unit.decoder_in : std_logic_vector(3 downto 0)>>;
end architecture;