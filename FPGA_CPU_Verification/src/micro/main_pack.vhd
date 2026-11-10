library ieee;
use ieee.std_logic_1164.all;
use work.sub_pack.all;

package main_pack is

   component micro_seq is
	   port( ir_code: in std_logic_vector(1 downto 0);
	        micro_op: out std_logic_vector(10 downto 0);
		          clk, res: in std_logic);
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

--microsequencer

library ieee;
use ieee.std_logic_1164.all;
use work.sub_pack.all;

entity micro_seq is
   port( ir_code: in std_logic_vector(1 downto 0);
	     micro_op: out std_logic_vector(10 downto 0);
		       clk, res: in std_logic		  );
end micro_seq;

architecture arc of micro_seq is
   signal next_addr, mem_in: std_logic_vector(3 downto 0);
	signal mem_out: std_logic_vector(15 downto 0);
	begin
	   micro_mux: mux2to1_nbit
		   generic map(n =>4)
			port map(
			   in1 => '1' & ir_code & '0' ,
			   in0 => mem_out(3 downto 0) ,
			     S => mem_out(15) ,
			     Y => next_addr
		);
		-- Reset: while res is 1, the ROM stores address 0000 (FETCH1)
		-- at the next rising clock edge
		mem_in <= "0000" when res = '1' else next_addr;
		memory: rom_microp
			port map(
				address =>mem_in ,
				clock => clk ,
				q =>mem_out
		);
      micro_op <= mem_out(14 downto 4);
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
   bus_out <=       mem_bus when (PDM="001") else
	           "00" & pc_bus when (PDM="100") else
		               dr_bus when (PDM="010") else
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

