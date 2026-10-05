library ieee;
use ieee.std_logic_1164.all;
use work.sub_pack.all;

package main_pack is

   component hw_control_unit is
      port(               ir_code: in std_logic_vector(1 downto 0);
	  	                   clk, res: in std_logic;
		     ARLOAD, PCLOAD, DRLOAD: out std_logic;
		             IRLOAD, ACLOAD: out std_logic;
		                     ALUSEL: out std_logic;
	          PCBUS, MEMBUS, DRBUS: out std_logic;
		               PCINC, ACINC: out std_logic
	);
   end component;
	
	component data_bus is
	   port( mem_bus: in std_logic_vector(7 downto 0);
	          pc_bus: in std_logic_vector(5 downto 0);
			    dr_bus: in std_logic_vector(7 downto 0);
			       PDM: in std_logic_vector(2 downto 0);
			   bus_out: out std_logic_vector(7 downto 0)
	   );
   end component;
	
	component alu_nbits is
	  generic(n: integer:= 8);
     port( dataA   : in  std_logic_vector(n-1 downto 0);
           dataB   : in  std_logic_vector(n-1 downto 0);
           alu_sel : in  std_logic;
           alu_out : out std_logic_vector(n-1 downto 0)
     );
	end component;
	
	component pipo_nbit is
   generic(n: integer:= 4);
		port(    D: in std_logic_vector(n-1 downto 0);
				load: in std_logic;
					Q: out std_logic_vector(n-1 downto 0);
				 CLK: in std_logic;
			    res: in std_logic
		);
   end component;
	
	component pipo_inc_nbit is
		generic(n: integer:= 4);
		port(    D: in std_logic_vector(n-1 downto 0);
		      load: in std_logic;
			      Q: out std_logic_vector(n-1 downto 0);
			    inc: in std_logic;
				 CLK: in std_logic;
		       res: in std_logic
		);
   end component;
	
	component external_mem is
		port
		(
			address	: in std_logic_vector (5 downto 0);
			clock		: in std_logic  := '1';
			  q		: out std_logic_vector (7 downto 0)
		);
   end component;

end package;

--hardwired cu

library ieee;
use ieee.std_logic_1164.all;
use work.sub_pack.all;

entity hw_control_unit is
   port(               ir_code: in std_logic_vector(1 downto 0);
	  	                clk, res: in std_logic;
		  ARLOAD, PCLOAD, DRLOAD: out std_logic;
		          IRLOAD, ACLOAD: out std_logic;
		                  ALUSEL: out std_logic;
	       PCBUS, MEMBUS, DRBUS: out std_logic;
		            PCINC, ACINC: out std_logic
	);
end hw_control_unit;

architecture arc of hw_control_unit is
   signal decoder_in: std_logic_vector(3 downto 0);
	signal lo: std_logic_vector(15 downto 0);
   begin
	   
		counter: counter_4bit
		   port map(
			     load => lo(2) ,
				   inc => (lo(0) or lo(1) or lo(8) or lo(10)), 
				   clr => (lo(9) or lo(11) or lo(12) or lo(14)),
			      clk => clk,
			      res => res,
			    input => ('1' & ir_code & '0'),
			   output => decoder_in
			);
      
		decoder: decoder_4to16
		   port map(
			    input => decoder_in,
	         output => lo
			);
		
		ARLOAD <= lo(0) or lo(2);
		PCLOAD <= lo(12);
		PCINC <= lo(1);
		DRLOAD <= lo(1) or lo(8) or lo(10);
		ACLOAD <= lo(9) or lo(11);
		ACINC <= lo(14);
		IRLOAD <= lo(2);
		ALUSEL <= lo(11);
		MEMBUS <= lo(1) or lo(8) or lo(10);
		PCBUS <= lo(0);
		DRBUS <= lo(2) or lo(9) or lo(11) or lo(12);
end arc;


--data bus

library ieee;
use ieee.std_logic_1164.all;

entity data_bus is
   port( mem_bus:in std_logic_vector(7 downto 0);
	       pc_bus:in std_logic_vector(5 downto 0);
			 dr_bus:in std_logic_vector(7 downto 0);
			    PDM:in std_logic_vector(2 downto 0);
			bus_out:out std_logic_vector(7 downto 0)
	);
end data_bus;

architecture arc of data_bus is
   begin
bus_out <= mem_bus when PDM = "001" else
           "00" & pc_bus when PDM = "100" else
           dr_bus when PDM = "010" else
           (others => '0');
end arc;

--alu nbits

library ieee;
use ieee.std_logic_1164.all;
use work.sub_pack.all;

entity alu_nbits is
  generic(n: integer := 8);
  port(
    dataA   : in  std_logic_vector(n-1 downto 0);
    dataB   : in  std_logic_vector(n-1 downto 0);
    alu_sel : in  std_logic;
    alu_out : out std_logic_vector(n-1 downto 0)
  );
end entity;

architecture arc of alu_nbits is
   signal sum : std_logic_vector(n-1 downto 0);
   begin
   addition: adder
     generic map(n => n)
     port map(
        A    => dataA,
        B    => dataB,
        S    => sum
      );

   mux: mux2to1_alu
     generic map(n => n)
     port map(
       asumb => sum,
       aandb => dataA and dataB,
       S     => alu_sel,
       Y     => alu_out
     );
	  
end architecture;

--pipo nbits

library ieee;
use ieee.std_logic_1164.all;

entity pipo_nbit is
   generic(n: integer:= 4);
   port(    D: in std_logic_vector(n-1 downto 0);
	      load: in std_logic;
	         Q: out std_logic_vector(n-1 downto 0);
          CLK: in std_logic;
		    res: in std_logic
	);
end pipo_nbit;

architecture arc of pipo_nbit is
   signal Qn: std_logic_vector(n-1 downto 0);
	begin
	pr1: process(CLK, res)
	   begin
		if (res='1') then
			Qn <= (others => '0');
		elsif rising_edge(CLK) then
		   if (load='1') then
			   Qn <= D;
		   end if;
		end if;
	end process;
	Q <= Qn;
end arc;

--pipo increment

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipo_inc_nbit is
   generic(n: integer:= 4);
   port(    D: in std_logic_vector(n-1 downto 0);
	      load: in std_logic;
	         Q: out std_logic_vector(n-1 downto 0);
	       inc: in std_logic;
          CLK: in std_logic;
	       res: in std_logic
	);
end pipo_inc_nbit;

architecture arc of pipo_inc_nbit is
   signal Qn: unsigned(n-1 downto 0) := (others => '0');
	begin
	pr1: process(CLK, res)
	   begin
		if (res='1') then
			Qn <= (others => '0');
		elsif rising_edge(CLK) then
		   if (load='1') then
			   Qn <= unsigned(D);
			elsif (inc='1') then
			   Qn <= Qn + 1;
		   end if;
		end if;
	end process;
	Q <= std_logic_vector(Qn);
end arc;

--external memory

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY external_mem IS
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END external_mem;


ARCHITECTURE SYN OF external_mem IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (7 DOWNTO 0);

BEGIN
	q    <= sub_wire0(7 DOWNTO 0);

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_aclr_a => "NONE",
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		init_file => "external_memory.mif",
		intended_device_family => "Cyclone V",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 64,
		operation_mode => "ROM",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		widthad_a => 6,
		width_a => 8,
		width_byteena_a => 1
	)
	PORT MAP (
		address_a => address,
		clock0 => clock,
		q_a => sub_wire0
	);

END SYN;
