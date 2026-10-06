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
