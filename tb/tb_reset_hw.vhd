-- Reset test for the hardwired CPU.
-- Checks that reset puts the control unit in FETCH1 (0000) and that
-- the CPU then steps through FETCH1 -> FETCH2 -> FETCH3.
-- Uses the Intel ROM model (altera_mf). Run from a folder that holds a
-- trimmed copy of external_memory.mif.

library ieee;
use ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

entity tb_reset_hw is
end entity;

architecture sim of tb_reset_hw is
  constant C_CLK_PERIOD : time := 20 ns;

  signal ARout, PCout          : std_logic_vector(5 downto 0);
  signal DRout, ACout, dataBus : std_logic_vector(7 downto 0);
  signal IRout                 : std_logic_vector(1 downto 0);
  signal mOP                   : std_logic_vector(10 downto 0);
  signal clock                 : std_logic := '0';
  signal reset                 : std_logic := '1';
begin
  clock <= not clock after C_CLK_PERIOD / 2;

  dut : entity work.vs_cpu_hw
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

  p_main : process
    -- The control unit's state, read from inside the CPU
    alias cu_state is <<signal .tb_reset_hw.dut.control_unit.decoder_in : std_logic_vector(3 downto 0)>>;
  begin
    log(ID_LOG_HDR, "Reset test, hardwired CPU");

    -- Reset is active from time 0. Check during reset, between clock edges.
    wait until rising_edge(clock);
    wait for C_CLK_PERIOD / 4;
    check_value(cu_state, "0000", ERROR, "State during reset is FETCH1");
    check_value(PCout, "000000", ERROR, "PC during reset is 0");

    -- Release reset away from a clock edge.
    reset <= '0';

    wait until rising_edge(clock);
    wait for C_CLK_PERIOD / 4;
    check_value(cu_state, "0001", ERROR, "State after 1st clock edge is FETCH2");

    wait until rising_edge(clock);
    wait for C_CLK_PERIOD / 4;
    check_value(cu_state, "0010", ERROR, "State after 2nd clock edge is FETCH3");
    check_value(PCout, "000001", ERROR, "PC incremented in FETCH2");

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process;
end architecture;
