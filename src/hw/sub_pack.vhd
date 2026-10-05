library ieee;
use ieee.std_logic_1164.all;

package sub_pack is
   
	component counter_4bit is
	  port(load, inc, clr, clk: in std_logic;
			             input: in std_logic_vector(3 downto 0);
			            output: out std_logic_vector(3 downto 0)
	);
   end component;
	
	component decoder_4to16 is
   port(  input: in std_logic_vector(3 downto 0);
	      output: out std_logic_vector(15 downto 0)
	);
   end component;
	
	component mux2to1_alu
		generic(n: integer:=8);
		port ( asumb: in std_logic_vector(n-1 downto 0);
			    aandb: in std_logic_vector(n-1 downto 0);
			        S: in std_logic;
			        Y: out std_logic_vector(n-1 downto 0)
		);
	end component;
	
	component adder
		generic(n: integer:=8);
		port (  A,B: in std_logic_vector(n-1 downto 0);
			       S: out std_logic_vector(n-1 downto 0)
		);
	end component;

end package;


--adder
library ieee;
use ieee.std_logic_1164.all;
entity adder is
   generic(n: integer:= 8);
   port(  A,B: in std_logic_vector(n-1 downto 0);
            S: out std_logic_vector(n-1 downto 0)
	);
end adder;
architecture dtf of adder is
   begin
      S <= A xor B;
end dtf;


--mux2to1
library ieee;
use ieee.std_logic_1164.all;

entity mux2to1_alu is
   generic(n: integer:= 8);
   port(  asumb: in std_logic_vector(n-1 downto 0);
	       aandb: in std_logic_vector(n-1 downto 0);
             S : in std_logic;
             Y : out std_logic_vector(n-1 downto 0)
   );
end mux2to1_alu;

architecture dtf of mux2to1_alu is
   begin
   Y <= asumb when (S = '0') else
        aandb when (S = '1') else
        (others => '0');
end dtf;

--counter

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter_4bit is
   port(load, inc, clr, clk: in std_logic;
			             input: in std_logic_vector(3 downto 0);
			            output: out std_logic_vector(3 downto 0)
	);
end counter_4bit;

architecture arc of counter_4bit is
	signal count: unsigned(3 downto 0);  
	begin
		process(clk)
		begin
			if rising_edge(clk) then
			if load='1' then
               count <=  unsigned(input);
            elsif clr='1' then
		count <= (others => '0');
            elsif inc='1' then
                count <= count + 1; 
				end if;
			end if;
		end process;
	output <= std_logic_vector(count);
end arc;


--decoder 4to16

library ieee;
use ieee.std_logic_1164.all;

entity decoder_4to16 is
   port(  input: in std_logic_vector(3 downto 0);
	      output: out std_logic_vector(15 downto 0)
	);
end decoder_4to16;

architecture arc of decoder_4to16 is
   begin
		process(input)
		begin
        output <= (others => '0'); 
        case input is
            when "0000" => output(0)  <= '1';  -- FETCH1
            when "0001" => output(1)  <= '1';  -- FETCH2
            when "0010" => output(2)  <= '1';  -- FETCH3
            when "1000" => output(8)  <= '1';  -- ADD1
            when "1001" => output(9)  <= '1';  -- ADD2
            when "1010" => output(10) <= '1';  -- AND1
            when "1011" => output(11) <= '1';  -- AND2
            when "1100" => output(12) <= '1';  -- JMP1
            when "1110" => output(14) <= '1';  -- INC1
            when others => null;
        end case;
		end process;
end arc;