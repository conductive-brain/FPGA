-- Compares the CPU in tb/cpu_dut_<cpu>.vhd with the reference model (tb/cpu_model_pkg.vhd).
-- For each program: reset the CPU, load the program, then after every
-- instruction check that the CPU's AC and PC equal the model's.
-- Programs: the original program, the carry program, then G_NUM_RANDOM random
-- programs. Random program number k uses the seeds (G_SEED, k), so the same
-- G_SEED always gives the same programs.
-- Coverage: during the random programs the test counts what was exercised
-- (each instruction, ADDs with a carry, wrap-arounds, self-jump loops),
-- prints the counts at the end, and checks that none of them is zero.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;
use work.mem_sim_pkg.all;
use work.cpu_model_pkg.all;

entity tb_model is
  generic (
    G_SEED           : positive := 1;    -- change it to get other random programs
    G_NUM_RANDOM     : natural  := 100;  -- how many random programs
    G_INSTR_PER_PROG : positive := 200   -- instructions per random program
  );
end entity;

architecture sim of tb_model is
  constant C_CLK_PERIOD     : time := 20 ns;
  constant C_MAX_INSTR_TIME : time := 10 * C_CLK_PERIOD;

  -- The two programs from the directed tests (tb_cpu.vhd)
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
      -- Coverage counters, filled by run_and_compare
    variable n_add, n_and, n_jmp, n_inc : natural := 0;  -- instructions run, per type
    variable n_add_carry : natural := 0;  -- ADDs where a carry changes the result (XOR would be wrong)
    variable n_add_wrap  : natural := 0;  -- ADDs whose sum passes 0xFF and wraps around
    variable n_inc_wrap  : natural := 0;  -- INCs from 0xFF to 0x00
    variable n_pc_wrap   : natural := 0;  -- PC going from 63 to 0
    variable n_stuck     : natural := 0;  -- programs that reached a JMP to itself
    variable n_useful    : natural := 0;  -- instructions run before each program got stuck

    -- Let the CPU run one instruction (same as in tb_cpu.vhd)
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
      -- For coverage: the instruction about to run, and its operand M[a]
      variable instr   : std_logic_vector(7 downto 0);
      variable a       : unsigned(5 downto 0);
      variable operand : unsigned(7 downto 0);
      variable stuck   : boolean := false;
    begin
      log(ID_SEQUENCER, "CPU vs model: " & name);

      -- Reset the CPU and load the program
      reset   <= '1';
      sim_mem <= program;
      wait until rising_edge(clock);
      wait for C_CLK_PERIOD / 4;
      reset   <= '0';

      for i in 1 to n loop
		        -- Coverage: look at the instruction before it runs
        instr   := program(to_integer(m_pc));
        a       := unsigned(instr(5 downto 0));
        operand := unsigned(program(to_integer(a)));
        case instr(7 downto 6) is
          when "00" =>                                    -- ADD
            n_add := n_add + 1;
            if (m_ac + operand) /= (m_ac xor operand) then
              n_add_carry := n_add_carry + 1;
            end if;
            if to_integer(m_ac) + to_integer(operand) > 255 then
              n_add_wrap := n_add_wrap + 1;
            end if;
          when "01" =>                                    -- AND
            n_and := n_and + 1;
          when "10" =>                                    -- JMP
            n_jmp := n_jmp + 1;
            if a = m_pc and not stuck then                -- JMP to itself: the program is stuck
              stuck    := true;
              n_stuck  := n_stuck + 1;
              n_useful := n_useful + i - 1;
            end if;
          when others =>                                  -- INC
            n_inc := n_inc + 1;
            if m_ac = x"FF" then
              n_inc_wrap := n_inc_wrap + 1;
            end if;
        end case;
        if m_pc = 63 and instr(7 downto 6) /= "10" then
          n_pc_wrap := n_pc_wrap + 1;
        end if;

        run_instruction;                  -- the CPU runs one instruction
        model_step(m_pc, m_ac, program);  -- the model runs the same one
        check_value(ACout, std_logic_vector(m_ac), ERROR, name & ", instruction " & to_string(i) & ": AC");
        check_value(PCout, std_logic_vector(m_pc), ERROR, name & ", instruction " & to_string(i) & ": PC");
      end loop;
      if not stuck then
        n_useful := n_useful + n;
      end if;
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
    -- Count coverage for the random programs only
    n_add := 0; n_and := 0; n_jmp := 0; n_inc := 0;
    n_add_carry := 0; n_add_wrap := 0; n_inc_wrap := 0; n_pc_wrap := 0;
    n_stuck := 0; n_useful := 0;

    log(ID_LOG_HDR, "Random programs: " & to_string(G_NUM_RANDOM) & " programs, "
                    & to_string(G_INSTR_PER_PROG) & " instructions each, G_SEED = " & to_string(G_SEED));
    for k in 1 to G_NUM_RANDOM loop
      seed1 := G_SEED;
      seed2 := k;
      random_program(seed1, seed2, program);
      run_and_compare("random program " & to_string(k), program, G_INSTR_PER_PROG);
    end loop;

    -- Coverage report
    log(ID_LOG_HDR, "Coverage of the random programs");
    log(ID_SEQUENCER, "Instructions run: ADD " & to_string(n_add) & ", AND " & to_string(n_and)
                      & ", JMP " & to_string(n_jmp) & ", INC " & to_string(n_inc));
    log(ID_SEQUENCER, "ADD with a carry (XOR would be wrong): " & to_string(n_add_carry) & " of " & to_string(n_add));
    log(ID_SEQUENCER, "ADD wrapping past 0xFF: " & to_string(n_add_wrap));
    log(ID_SEQUENCER, "INC from 0xFF to 0x00: " & to_string(n_inc_wrap));
    log(ID_SEQUENCER, "PC from 63 to 0: " & to_string(n_pc_wrap));
    log(ID_SEQUENCER, "Programs stuck in a JMP to itself: " & to_string(n_stuck) & " of " & to_string(G_NUM_RANDOM));
    log(ID_SEQUENCER, "Instructions before getting stuck (the useful ones): " & to_string(n_useful)
                      & " of " & to_string(G_NUM_RANDOM * G_INSTR_PER_PROG));

    -- Each case must have happened at least once
    if G_NUM_RANDOM > 0 then
      check_value(n_add > 0,       ERROR, "Coverage: ADD ran");
      check_value(n_and > 0,       ERROR, "Coverage: AND ran");
      check_value(n_jmp > 0,       ERROR, "Coverage: JMP ran");
      check_value(n_inc > 0,       ERROR, "Coverage: INC ran");
      check_value(n_add_carry > 0, ERROR, "Coverage: ADD with a carry");
      check_value(n_add_wrap > 0,  ERROR, "Coverage: ADD wrapping past 0xFF");
      check_value(n_inc_wrap > 0,  ERROR, "Coverage: INC from 0xFF to 0x00");
      check_value(n_pc_wrap > 0,   ERROR, "Coverage: PC from 63 to 0");
    end if;
    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process;
end architecture;