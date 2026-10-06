-- Reference model of the Very Simple CPU, at instruction level.
-- One call to model_step runs one instruction. No clock, no states:
-- only the rules from the instruction table (PROJECT_GUIDE.md, section 6).
-- It uses VHDL's own "+", not the CPU's adder, so a bug in the CPU's
-- adder shows up as a difference between the CPU and the model.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_sim_pkg.all;

package cpu_model_pkg is
  procedure model_step(
    variable pc  : inout unsigned(5 downto 0);
    variable ac  : inout unsigned(7 downto 0);
    constant mem : in    mem_t
  );
end package;

package body cpu_model_pkg is
  procedure model_step(
    variable pc  : inout unsigned(5 downto 0);
    variable ac  : inout unsigned(7 downto 0);
    constant mem : in    mem_t
  ) is
    variable instr  : std_logic_vector(7 downto 0);
    variable opcode : std_logic_vector(1 downto 0);
    variable a      : unsigned(5 downto 0);
  begin
    -- Fetch: read the instruction at PC, split it, move PC on
    instr  := mem(to_integer(pc));
    opcode := instr(7 downto 6);
    a      := unsigned(instr(5 downto 0));
    pc     := pc + 1;                                   -- 63 + 1 wraps to 0

    -- Execute
    case opcode is
      when "00"   => ac := ac + unsigned(mem(to_integer(a)));    -- ADD a
      when "01"   => ac := ac and unsigned(mem(to_integer(a)));  -- AND a
      when "10"   => pc := a;                                    -- JMP a
      when others => ac := ac + 1;                               -- INC
    end case;
  end procedure;
end package body;