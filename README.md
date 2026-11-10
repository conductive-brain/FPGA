# Verification of an 8-bit VHDL CPU

![GHDL tests](https://github.com/conductive-brain/FPGA_CPU_Verification/actions/workflows/sim.yml/badge.svg)

An 8-bit CPU in VHDL in two versions, one with a hardwired and one with a microprogrammed control unit, and a
self-checking UVVM testbench that verifies both. The tests run in GHDL on every push through GitHub Actions.

I designed the CPU and ran it on a Cyclone V board (Terasic DE10-Standard). At the time I checked it
by reading simulation waveforms. This repository adds automated verification: directed tests, a reference model,
random programs and coverage. The original design had four problems that the waveforms had not shown. Each fix is a separate
commit together with the test that shows the problem.

## The CPU

| Register | Width  | Role                              |
|----------|--------|-----------------------------------|
| PC       | 6 bits | Address of the next instruction   |
| AR       | 6 bits | Address register                  |
| DR       | 8 bits | Data register                     |
| AC       | 8 bits | Accumulator                       |
| IR       | 2 bits | Opcode of the current instruction |

Memory: 64 words of 8 bits, read-only, holding both the program and its data. Each instruction is one byte: bits 7:6
are the opcode, bits 5:0 an address `a`. Every byte is a valid instruction.

| Opcode | Instruction | Effect                                 | Clock cycles |
|--------|-------------|----------------------------------------|--------------|
| 00     | ADD a       | AC <- AC + M[a] (8 bits, wraps around) | 5            |
| 01     | AND a       | AC <- AC and M[a]                      | 5            |
| 10     | JMP a       | PC <- a                                | 4            |
| 11     | INC         | AC <- AC + 1                           | 4            |

Each instruction starts with three fetch states (FETCH1 to FETCH3) and ends by returning to FETCH1 (state 0000).

- `src/hw`: hardwired control unit. A 4-bit counter holds the state and a decoder drives the control signals.
- `src/micro`: microprogrammed control unit. A 16 x 16-bit microcode ROM (`microcode.mif`) holds the control
  signals and the next address. The ROM's registered address is the state.

## Repository layout

```
src/hw/        hardwired CPU and its Quartus project
src/micro/     microprogrammed CPU and its Quartus project
tb/            testbench, simulation models, reference model
scripts/       run_ghdl.ps1 (Windows) and run_ghdl.sh (Linux, Git Bash): run every test on both CPUs in GHDL;
               run_modelsim.ps1: the same in ModelSim
.github/       GitHub Actions workflow
```

## How the tests work

- **Memory models.** The board design uses Intel's `altsyncram` ROM blocks (`src/*/*_altera.vhd`), which need
  Quartus libraries. The tests use VHDL models with the same ports and timing (address stored on the rising clock
  edge, output not registered): `tb/external_mem_sim.vhd` for the program memory, which the testbench fills with a
  new program for every test, and `tb/rom_microp_sim.vhd` for the microcode ROM, which reads the same
  `microcode.mif` as Quartus.
- **One testbench, two CPUs.** The tests connect to a wrapper, `cpu_dut`, with one file per CPU
  (`tb/cpu_dut_hw.vhd`, `tb/cpu_dut_micro.vhd`). The wrapper brings the control unit state out to the testbench.
  A return to FETCH1 marks the end of an instruction.
- **`tb_reset`**: reset puts the control unit in FETCH1 and the CPU fetches its first instruction.
- **`tb_cpu`**: three hand-written programs with expected values worked out by hand: the original program,
  an addition with carries (0x27 + 0x39 = 0x60), and INC from 0xFF to 0x00.
- **`tb_model`**: compares the CPU with a reference model (`tb/cpu_model_pkg.vhd`) after every instruction.
  The model applies the instruction table directly and uses VHDL's own addition, not the CPU's adder. It runs the
  two first directed programs, then 100 random programs of 200 instructions each. Random program k uses the seeds
  (G_SEED, k), so any failing program can be run again.
- **Coverage**: `tb_model` counts what the random programs exercised and fails if any count is zero.

## Problems in the original design and their fixes

1. **The hw control unit's state counter had no reset.** The board worked only because the FPGA powers up with
   every register at 0.
   - How it showed up: `tb_reset` saw state `UUUU` instead of 0000 (FETCH1).
   - Fix: 0a3c339
2. **The original adder computed A xor B instead of A + B** (hw and micro). XOR raised Fmax, and the original
   programs never produced a carry, so the waveforms looked right. The fix restores a ripple-carry adder.
   - How it showed up: in `tb_cpu`, 0x27 + 0x39 gave 0x1E instead of 0x60. `tb_model` also catches it within the
     first random program.
   - Fix: e923b67 (hw), f571dc8 (micro)
3. **The micro version's memory instance was bound to a file outside the project.**
   - How it showed up: Quartus, run from the project folder, stopped with Error 12006 (undefined entity
     `external_mem`).
   - Fix: 0a39bc8
4. **The micro version's microsequencer had no reset.**
   - How it showed up: `tb_reset` saw state `ZZZZ` instead of 0000.
   - Fix: f571dc8

The microcode ROM sits in an M10K block, whose address register has no plain reset input. The micro version
therefore feeds address 0000 to the ROM while reset is active (synchronous reset).

## Coverage

Random programs with G_SEED = 1, same counts on both CPUs:

| Item                                             | Count                                      |
|--------------------------------------------------|--------------------------------------------|
| ADD / AND / JMP / INC run                        | 4043 / 4131 / 7505 / 4321                  |
| ADD with a carry (XOR would give a wrong result) | 2955 of 4043                               |
| ADD wrapping past 0xFF                           | 1473                                       |
| INC from 0xFF to 0x00                            | 3 (too few, so `tb_cpu` tests it directly) |
| PC from 63 to 0                                  | 299                                        |
| Programs that end in a JMP to itself             | 11 of 100                                  |
| Instructions run before that point               | 17905 of 20000                             |

## Timing

Quartus Prime Lite 18.1, device 5CSXFC6D6F31C6, Timing Analyzer with the slow 1100 mV 85 °C model.

### Constraints

`src/hw/vs_cpu_hw.sdc` and `src/micro/vs_cpu.sdc` set a 20 ns clock, the board's 50 MHz oscillator (CLOCK_50), and
add Intel's clock uncertainty. `reset` (a push-button) and the outputs (they only show the registers) are not timed.
The projects have no pin assignments yet; the clock input is meant for CLOCK_50.

### Results at 50 MHz

| CPU   | Setup slack | Hold slack | Fmax of this build |
|-------|-------------|------------|--------------------|
| hw    | +13.638 ns  | +0.333 ns  | 157.18 MHz         |
| micro | +12.581 ns  | +0.332 ns  | 134.79 MHz         |

Both CPUs meet the 50 MHz clock with more than 12 ns to spare, and no input or output is left unconstrained. Fmax is
lower than in the table below because the Fitter stops optimizing once a design meets its target.

### Fmax before and after the fixes

Compiled without an SDC file, so against Quartus's default 1 ns target:

| CPU   | Before (XOR adder, no reset) | After the fixes |
|-------|------------------------------|-----------------|
| hw    | 258.13 MHz                   | 226.55 MHz      |
| micro | 203.67 MHz                   | 182.22 MHz      |

The micro version's slowest path starts at the M10K microcode ROM. In a trial with the microcode written as a VHDL
table, Quartus built it from logic and micro Fmax (XOR adder) rose from 203.67 MHz to 250.5 MHz. The board design
keeps the M10K ROM.

### The slowest path (hw, 4 ns experiment)

With a 4 ns target the hw build reaches 212.09 MHz. Its worst path runs from the program memory through the data bus
and the adder into AC and needs 4.715 ns: 2.263 ns in the memory block (its clock arrives late, then the read),
1.380 ns in wires, 0.683 ns in logic, the rest in the AC register and the clock uncertainty.

The CPU never uses this path within one clock cycle: AC loads only in ADD2 and AND2, when the bus carries DR, not the
memory. The slowest path it does use, from the control unit to AC, would allow about 234 MHz in that build. A timing
exception (`set_false_path`) could tell Quartus so. The SDC files have none: at 50 MHz both CPUs have more than
12 ns of slack, and a wrong exception would hide real failures that no simulation catches.

## What the tests do not check

- Intel's ROM blocks themselves. The tests use models with the same ports and timing.
- Timing. GHDL simulates logic without delays. The Quartus Timing Analyzer checks timing separately (see Timing).

## Running the tests

Requirements:

- GHDL 6.0.0 (mcode backend)
- UVVM 2026.03.20, with the `uvvm_util` library compiled for GHDL

GHDL settings used in every phase (analyse, elaborate, run):

| Flag        | Why                                                                              |
|-------------|----------------------------------------------------------------------------------|
| `--std=08`  | VHDL-2008, which UVVM requires                                                   |
| `-frelaxed` | UVVM uses shared variables of plain types, which strict VHDL-2008 does not allow |
| `-P<dir>`   | Where the compiled UVVM libraries are                                            |

Compile `uvvm_util` (from the UVVM download, into `<dir>/uvvm_util/v08`):

```bash
mkdir -p "$UVVM_LIB/uvvm_util/v08"
grep -v '^#' uvvm/uvvm_util/script/compile_order.txt | while read -r f; do
  ghdl -a --std=08 -frelaxed --work=uvvm_util --workdir="$UVVM_LIB/uvvm_util/v08" "uvvm/uvvm_util/script/$f"
done
```

Run all tests on both CPUs. Exit code 0 means every test passed.

Windows (PowerShell, UVVM compiled in `%USERPROFILE%\tools\uvvm_ghdl`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_ghdl.ps1
```

Linux or Git Bash (UVVM in `$UVVM_LIB`, default `<user folder>/tools/uvvm_ghdl`):

```bash
bash scripts/run_ghdl.sh
```

ModelSim (Intel FPGA Starter Edition 10.5b, part of Quartus Prime Lite 18.1), Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_modelsim.ps1
```

The first run compiles `uvvm_util` for ModelSim into `%USERPROFILE%\tools\uvvm_modelsim`. ModelSim returns exit
code 0 even when a test fails, so the script decides from each test's output: a test passes only if its output
contains "Simulation SUCCESS" and no "ERROR #". All tests pass in ModelSim, with the same coverage counts as in GHDL.

Run the model test with other random programs, for example seed 7, after a normal run:

```bash
cd sim_out/run_hw
ghdl -r --std=08 -frelaxed -P"$UVVM_LIB" tb_model -gG_SEED=7
```

## Continuous integration

`.github/workflows/sim.yml` runs on every push: it installs GHDL 6.0.0, downloads UVVM 2026.03.20, compiles
`uvvm_util` and runs `scripts/run_ghdl.sh`. A run takes about 30 s.

## Building for the board

Open `src/hw/vs_cpu_hw.qpf` or `src/micro/vs_cpu.qpf` in Quartus Prime Lite 18.1. Each project includes its SDC
file. Pin assignments still have to be added before loading a design onto the board.

## License

MIT, see [LICENSE](LICENSE). The Quartus project files (`*.qpf`, `*.qsf`) start with Intel's standard notice,
which Quartus writes into the files it generates.
