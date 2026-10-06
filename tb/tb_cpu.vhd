-- Directed tests for the CPU in tb/cpu_dut_<cpu>.vhd.
-- Loads a hand-written program into the simulation memory, runs it one
-- instruction at a time, and checks AC and PC after each instruction.

library ieee;
use ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use work.mem_sim_pkg.all;

entity tb_cpu is
end entity;

architecture sim of tb_cpu is
  constant C_CLK_PERIOD : time := 20 ns;
  -- The longest instruction takes 5 clock cycles (guide, section 6).
  -- Allow twice that before calling it stuck.
  constant C_MAX_INSTR_TIME : time := 10 * C_CLK_PERIOD;

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

    -- Let the CPU run one instruction. Every instruction ends by going back
    -- to FETCH1 (0000), so wait for that. Then wait a quarter clock period,
    -- so the registers show their new values.
    procedure run_instruction is
    begin
      wait until cu_state = "0000" for C_MAX_INSTR_TIME;
      check_value(cu_state, "0000", ERROR, "Instruction finished in time");
      wait for C_CLK_PERIOD / 4;
    end procedure;

  begin
    log(ID_LOG_HDR, "Directed test 1: hw original program");

    -- Load the hw original program (same bytes as src/hw/external_memory.mif)
    sim_mem <= (0 => x"C0", 1 => x"C0", 2 => x"05", 3 => x"46",
                4 => x"84", 5 => x"08", 6 => x"02", others => x"00");

    -- Hold reset until the first clock edge, then release it between edges
    wait until rising_edge(clock);
    wait for C_CLK_PERIOD / 4;
    reset <= '0';

    -- Address 0: INC
    run_instruction;
    check_value(ACout, x"01", ERROR, "INC: AC = 0x00 + 1");
    check_value(PCout, "000001", ERROR, "INC: PC = 1");
	 
    -- Address 1: INC
    run_instruction;
    check_value(ACout, x"02", ERROR, "INC: AC = 0x01 + 1");
    check_value(PCout, "000010", ERROR, "INC: PC = 2");

    -- Address 2: ADD 5 (M[5] = 0x08)
    run_instruction;
    check_value(ACout, x"0A", ERROR, "ADD 5: AC = 0x02 + 0x08");
    check_value(PCout, "000011", ERROR, "ADD 5: PC = 3");

    -- Address 3: AND 6 (M[6] = 0x02)
    run_instruction;
    check_value(ACout, x"02", ERROR, "AND 6: AC = 0x0A and 0x02");
    check_value(PCout, "000100", ERROR, "AND 6: PC = 4");

    -- Address 4: JMP 4
    run_instruction;
    check_value(ACout, x"02", ERROR, "JMP 4: AC unchanged");
    check_value(PCout, "000100", ERROR, "JMP 4: PC = 4");

    -- Address 4 again: JMP 4 jumps to itself, so nothing changes
    run_instruction;
    check_value(ACout, x"02", ERROR, "JMP 4 (loop): AC unchanged");
    check_value(PCout, "000100", ERROR, "JMP 4 (loop): PC = 4");
	 
    log(ID_LOG_HDR, "Directed test 2: ADD with carries (0x27 + 0x39)");

    -- Reset the CPU and load a new program
    reset <= '1';
    sim_mem <= (0 => x"04", 1 => x"05", 2 => x"82",
                4 => x"27", 5 => x"39", others => x"00");
    wait until rising_edge(clock);
    wait for C_CLK_PERIOD / 4;
    reset <= '0';

    -- Address 0: ADD 4 (M[4] = 0x27), no carry
    run_instruction;
    check_value(ACout, x"27", ERROR, "ADD 4: AC = 0x00 + 0x27");
    check_value(PCout, "000001", ERROR, "ADD 4: PC = 1");

    -- Address 1: ADD 5 (M[5] = 0x39), carries in 6 of 8 bits
    run_instruction;
    check_value(ACout, x"60", ERROR, "ADD 5: AC = 0x27 + 0x39 = 0x60");
    check_value(PCout, "000010", ERROR, "ADD 5: PC = 2");

    log(ID_LOG_HDR, "Directed test 3: INC from 0xFF to 0x00");

    -- Reset the CPU and load a new program
    reset <= '1';
    sim_mem <= (0 => x"04", 1 => x"C0", 2 => x"C0", 3 => x"83",
                4 => x"FF", others => x"00");
    wait until rising_edge(clock);
    wait for C_CLK_PERIOD / 4;
    reset <= '0';

    -- Address 0: ADD 4 (M[4] = 0xFF), so AC = 0xFF
    run_instruction;
    check_value(ACout, x"FF", ERROR, "ADD 4: AC = 0x00 + 0xFF");
    check_value(PCout, "000001", ERROR, "ADD 4: PC = 1");

    -- Address 1: INC, AC wraps from 0xFF to 0x00
    run_instruction;
    check_value(ACout, x"00", ERROR, "INC: AC = 0xFF + 1 wraps to 0x00");
    check_value(PCout, "000010", ERROR, "INC: PC = 2");

    -- Address 2: INC again, counting goes on from 0x00
    run_instruction;
    check_value(ACout, x"01", ERROR, "INC: AC = 0x00 + 1");
    check_value(PCout, "000011", ERROR, "INC: PC = 3");
    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process;
end architecture;