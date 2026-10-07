# Timing constraints for the microprogrammed CPU, read by the Quartus Timing Analyzer.

# The clock: the DE10-Standard's 50 MHz oscillator (CLOCK_50, board user manual,
# Table 3-5), so the period is 20 ns.
create_clock -name clock -period 20.000 [get_ports clock]

# Add Intel's margin for clock jitter and other clock uncertainty.
derive_clock_uncertainty

# reset comes from a push-button, at any time, with no relation to the clock.
# It is not timed. (A product design would pass it through a reset synchronizer.)
set_false_path -from [get_ports reset]

# The outputs only show the CPU's registers to a person (LEDs, displays or a
# logic analyzer). Nothing samples them on the clock, so they are not timed.
set_false_path -to [get_ports {ARout[*] PCout[*] DRout[*] ACout[*] IRout[*] dataBus[*] mOP[*]}]