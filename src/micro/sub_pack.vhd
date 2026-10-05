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

--microprogrammed rom

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY rom_microp IS
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END rom_microp;

ARCHITECTURE SYN OF rom_microp IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (15 DOWNTO 0);

BEGIN
	q    <= sub_wire0(15 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_aclr_a => "NONE",
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		init_file => "microcode.mif",
		intended_device_family => "Cyclone V",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 16,
		operation_mode => "ROM",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		widthad_a => 4,
		width_a => 16,
		width_byteena_a => 1
	)
	PORT MAP (
		address_a => address,
		clock0 => clock,
		q_a => sub_wire0
	);
END SYN;

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
        (others => 'Z');
end dtf;
