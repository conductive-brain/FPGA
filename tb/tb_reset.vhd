-- Reset test for the CPU in tb/cpu_dut_<cpu>.vhd.
-- Checks that reset puts the control unit in FETCH1 (0000) and that
-- the CPU then steps through FETCH1 -> FETCH2 -> FETCH3.
-- Uses the simulation memory (tb/external_mem_sim.vhd), loaded with the
-- hw original program.

library ieee;
use ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use work.mem_sim_pkg.all;

entity tb_reset is
end entity;

architecture sim of tb_reset is
  constant C_CLK_PERIOD : time := 20 ns;

  signal ARout, PCout          : std_logic_vector(5 downto 0);
  signal DRout, ACout, dataBus : std_logic_vector(7 downto 0);
  signal IRout                 : std_logic_vector(1 downto 0);
  signal mOP                   : std_logic_vector(10 downto 0);
  signal clock                 : std_logic := '0';
  signal reset                 : std_logic := '1';
  signal cu_state              : std_logic_vector(3 downto 0);  -- control unit state
begin
  clock <= not clock after C_CLK_PERIOD / 2;

  dut : entity work.cpu_dut
    port map (
      ARout   => ARout,
      PCout   => PCout,
      DRout   => DRout,
      ACout   => ACout,
      IRout   => IRout,
      dataBus => dataBus,
      clock   => clock,
      reset   => reset,
      mOP     => mOP,
      cu_state => cu_state
    );

  p_main : process
  begin
    log(ID_LOG_HDR, "Reset test");
	     -- Load the hw original program (same bytes as src/hw/external_memory.mif)
    sim_mem <= (0 => x"C0", 1 => x"C0", 2 => x"05", 3 => x"46",
                4 => x"84", 5 => x"08", 6 => x"02", others => x"00");

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
	 check_value(DRout, x"C0", ERROR, "DR holds the first instruction, M[0]");

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process;
end architecture;
