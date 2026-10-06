library ieee;
use ieee.std_logic_1164.all;

package sub_pack is

	component mux2to1_nbit is
      generic(n: integer:= 4);
      port( in0, in1: in std_logic_vector(n-1 downto 0);
                  S : in std_logic;
                  Y : out std_logic_vector(n-1 downto 0)
      );
   end component;
   
	component rom_microp is
	port( address: in std_logic_vector (3 downto 0);
		     clock: in std_logic:= '1';
		         q: out std_logic_vector (15 downto 0)
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

--mux2to1
library ieee;
use ieee.std_logic_1164.all;

entity mux2to1_nbit is
   generic(n: integer:= 8);
   port( in0, in1: in std_logic_vector(n-1 downto 0);
               S : in std_logic;
               Y : out std_logic_vector(n-1 downto 0)
   );
end mux2to1_nbit;

architecture dtf of mux2to1_nbit is
   begin
   Y <=  in1 when (S = '1') else
         in0 when (S = '0') else
         (others => 'Z');
end dtf;

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
   signal carry: std_logic_vector(n downto 0);
   begin
   carry(0) <= '0';
   gen: for i in 0 to n-1 generate
      begin
      S(i) <= A(i) xor B(i) xor carry(i);
      carry(i+1) <= ( A(i) and B(i)) or
                    ( A(i) and carry(i)) or
                    ( B(i) and carry(i));
   end generate;
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
        (others => 'Z');
end dtf;
