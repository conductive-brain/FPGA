library ieee;
use ieee.std_logic_1164.all;
use work.main_pack.all;

entity vs_cpu_hw is
  port( ARout, PCout: buffer std_logic_vector(5 downto 0);
	 	  DRout, ACout: buffer std_logic_vector(7 downto 0);
	  	         IRout: buffer std_logic_vector(1 downto 0);
	          dataBus: buffer std_logic_vector(7 downto 0);
		  clock, reset: in std_logic;
	  	           mOP: buffer std_logic_vector(10 downto 0));
end entity vs_cpu_hw;

architecture arc of vs_cpu_hw is
   signal logic_out, mem_in: std_logic_vector (7 downto 0);
	signal tristate: std_logic_vector (2 downto 0);
	signal ar_in: std_logic_vector (5 downto 0);
	signal micro_code: std_logic_vector (1 downto 0);
   signal ARLOAD, IRLOAD, PCLOAD: std_logic;
	signal DRLOAD, ACLOAD: std_logic;
   signal MEMBUS, PCBUS, DRBUS : std_logic;
   signal ACINC, PCINC : std_logic;
   signal ALUSEL : std_logic;

	begin
	tristate <= PCBUS & DRBUS & MEMBUS;
	micro_code <= dataBus(7 downto 6); 
	
	data: data_bus
		port map(
			mem_bus => mem_in,
			 pc_bus => PCout,
			 dr_bus => DRout,
				 PDM => tristate,
			bus_out => dataBus
		);
		
   alu: alu_nbits
	   generic map(n => 8)
		port map(
		     dataA => ACout,
           dataB => dataBus,
         alu_sel => mOP(3),
         alu_out => logic_out
		);
		
	control_unit: hw_control_unit
      port map(
		    ir_code => micro_code,
		        clk => clock,
			  ARLOAD => ARLOAD,
			  PCLOAD => PCLOAD,
				PCINC => PCINC, 
			  DRLOAD => DRLOAD,
			  ACLOAD => ACLOAD,
				ACINC => ACINC,
			  IRLOAD => IRLOAD,
			  ALUSEL => ALUSEL,
			  MEMBUS => MEMBUS,
				PCBUS => PCBUS,
				DRBUS => DRBUS
		  );
		  
	ar: pipo_nbit
      generic map(n => 6)
	   port map(
		       D => dataBus(5 downto 0),
			 load => mOP(10),
			    Q => ARout,
			  CLK => clock,
			  res => reset
		);
		
   pc: pipo_inc_nbit
	   generic map(n => 6)
		port map(
		       D => dataBus(5 downto 0),
		    load => mOP(9),
			    Q => PCout,
			  inc => mOP(8),
			  CLK => clock,
		     res => reset
		);
	
	dr: pipo_nbit
      generic map(n => 8)
	   port map(
		       D => dataBus,
			 load => mOP(7),
			    Q => DRout,
			  CLK => clock,
			  res => reset
		);
	
	ac: pipo_inc_nbit
	   generic map(n => 8)
		port map(
		       D => logic_out,
		    load => mOP(6),
			    Q => ACout,
			  inc => mOP(5),
			  CLK => clock,
		     res => reset
		);
	
	ir: pipo_nbit
      generic map(n => 2)
	   port map(
		       D => micro_code,
			 load => mOP(4),
			    Q => IRout,
			  CLK => clock,
			  res => reset
		);
			
	 external_memory: external_mem
      port map(
	      address => dataBus(5 downto 0),
		     clock => clock,
		         q => mem_in
		);

	mOP(0) <= MEMBUS;
   mOP(1) <= DRBUS;
   mOP(2) <= PCBUS ;	
   mOP(3) <= ALUSEL;	
   mOP(4) <= IRLOAD;	
   mOP(5) <= ACINC;
   mOP(6) <= ACLOAD;	
   mOP(7) <= DRLOAD;	
   mOP(8) <= PCINC;
   mOP(9) <= PCLOAD;	
   mOP(10)<= ARLOAD;		
	
end arc;

