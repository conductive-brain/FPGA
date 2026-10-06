-- Compares the hardwired CPU with the reference model (tb/cpu_model_pkg.vhd).
-- For each program: reset the CPU, load the program, then after every
-- instruction check that the CPU's AC and PC equal the model's.
-- Programs: the original program, the carry program, then G_NUM_RANDOM random
-- programs. Random program number k uses the seeds (G_SEED, k), so the same
-- G_SEED always gives the same programs.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use work.mem_sim_pkg.all;
use work.cpu_model_pkg.all;

entity tb_model_hw is
  generic (
    G_SEED           : positive := 1;    -- change it to get other random programs
    G_NUM_RANDOM     : natural  := 100;  -- how many random programs
    G_INSTR_PER_PROG : positive := 200   -- instructions per random program
  );
end entity;

architecture sim of tb_model_hw is
  constant C_CLK_PERIOD     : time := 20 ns;
  constant C_MAX_INSTR_TIME : time := 10 * C_CLK_PERIOD;

  -- The two programs from the directed tests (tb_cpu_hw.vhd)
  constant C_ORIG_PROGRAM : mem_t := (0 => x"C0", 1 => x"C0", 2 => x"05", 3 => x"46",
                                      4 => x"84", 5 => x"08", 6 => x"02", others => x"00");
  constant C_CARRY_PROGRAM : mem_t := (0 => x"04", 1 => x"05", 2 => x"82",
                                       4 => x"27", 5 => x"39", others => x"00");

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
    alias cu_state is <<signal .tb_model_hw.dut.control_unit.decoder_in : std_logic_vector(3 downto 0)>>;

    -- Let the CPU run one instruction (same as in tb_cpu_hw.vhd)
    procedure run_instruction is
    begin
      wait until cu_state = "0000" for C_MAX_INSTR_TIME;
      check_value(cu_state, "0000", ERROR, "Instruction finished in time");
      wait for C_CLK_PERIOD / 4;
    end procedure;

    -- Run a program on the CPU and on the model, n instructions,
    -- comparing AC and PC after each one
    procedure run_and_compare(
      constant name    : in string;
      constant program : in mem_t;
      constant n       : in positive
    ) is
      -- The model's registers, starting from the reset values
      variable m_pc : unsigned(5 downto 0) := (others => '0');
      variable m_ac : unsigned(7 downto 0) := (others => '0');
    begin
      log(ID_SEQUENCER, "CPU vs model: " & name);

      -- Reset the CPU and load the program
      reset   <= '1';
      sim_mem <= program;
      wait until rising_edge(clock);
      wait for C_CLK_PERIOD / 4;
      reset   <= '0';

      for i in 1 to n loop
        run_instruction;                  -- the CPU runs one instruction
        model_step(m_pc, m_ac, program);  -- the model runs the same one
        check_value(ACout, std_logic_vector(m_ac), ERROR, name & ", instruction " & to_string(i) & ": AC");
        check_value(PCout, std_logic_vector(m_pc), ERROR, name & ", instruction " & to_string(i) & ": PC");
      end loop;
    end procedure;

    -- Fill a program with 64 random bytes. Every byte is a valid
    -- instruction on this CPU, so any random program can run.
    procedure random_program(
      variable seed1, seed2 : inout positive;
      variable program      : out   mem_t
    ) is
      variable r : real;  -- random number between 0.0 and 1.0
    begin
      for addr in 0 to 63 loop
        uniform(seed1, seed2, r);
        program(addr) := std_logic_vector(to_unsigned(integer(trunc(r * 256.0)), 8));
      end loop;
    end procedure;

    variable seed1, seed2 : positive;
    variable program      : mem_t;

  begin
    -- Print only errors and summaries, not every passing check
    disable_log_msg(ID_POS_ACK);
    run_and_compare("original program", C_ORIG_PROGRAM,  10);
    run_and_compare("carry program",    C_CARRY_PROGRAM, 10);

    log(ID_LOG_HDR, "Random programs: " & to_string(G_NUM_RANDOM) & " programs, "
                    & to_string(G_INSTR_PER_PROG) & " instructions each, G_SEED = " & to_string(G_SEED));
    for k in 1 to G_NUM_RANDOM loop
      seed1 := G_SEED;
      seed2 := k;
      random_program(seed1, seed2, program);
      run_and_compare("random program " & to_string(k), program, G_INSTR_PER_PROG);
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process;
end architecture;