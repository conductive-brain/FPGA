#!/usr/bin/env bash
# Runs all GHDL tests on every CPU version. Linux version of run_ghdl.ps1:
# GitHub Actions runs this one. It also runs in Git Bash on Windows.
# Use, from the project folder:
#   bash scripts/run_ghdl.sh
# The compiled UVVM libraries are found through the variable UVVM_LIB.
# Default: <your user folder>/tools/uvvm_ghdl.
# Exit code: 0 = all tests passed, anything else = a test failed.

# Project folder = the folder above this script's folder
root="$(cd "$(dirname "$0")/.." && pwd)"

# GHDL settings (PROJECT_GUIDE.md, section 4)
# User folder: USERPROFILE on Windows (HOME can point elsewhere there),
# HOME on Linux
user_dir="${USERPROFILE:-$HOME}"
uvvm_lib="${UVVM_LIB:-$user_dir/tools/uvvm_ghdl}"
# In Git Bash on Windows, turn /c/Users/... into C:/Users/... for GHDL.
# cygpath only exists there; on Linux this line does nothing.
if command -v cygpath > /dev/null; then uvvm_lib="$(cygpath -m "$uvvm_lib")"; fi
opts=(--std=08 -frelaxed "-P$uvvm_lib")

# The tests, in the order they run. Each one is tb/<name>.vhd
tests=(tb_reset tb_cpu tb_model)

# The CPU versions and their design files. Each one also has a wrapper,
# tb/cpu_dut_<name>.vhd, that the tests connect to.
cpus=(hw micro)
hw_files=("$root/src/hw/sub_pack.vhd" "$root/src/hw/main_pack.vhd" "$root/src/hw/vs_cpu_hw.vhd")
micro_files=("$root/src/micro/sub_pack.vhd" "$root/src/micro/main_pack.vhd" "$root/tb/rom_microp_sim.vhd" "$root/src/micro/vs_cpu.vhd")

for cpu in "${cpus[@]}"; do
  echo "########## CPU: $cpu ##########"

  # Fresh run folder for this CPU: delete the old one, make a new one
  run="$root/sim_out/run_$cpu"
  rm -rf "$run"
  mkdir -p "$run"

  # The micro version's ROM model (tb/rom_microp_sim.vhd) reads microcode.mif
  # from the run folder
  if [ -f "$root/src/$cpu/microcode.mif" ]; then
    cp "$root/src/$cpu/microcode.mif" "$run/"
  fi

  # All files, in the order GHDL needs them: simulation memory and model,
  # the CPU, its wrapper, then the tests
  files=("$root/tb/mem_sim_pkg.vhd" "$root/tb/external_mem_sim.vhd" "$root/tb/cpu_model_pkg.vhd")
  if [ "$cpu" = "hw" ]; then
    files+=("${hw_files[@]}")
  else
    files+=("${micro_files[@]}")
  fi
  files+=("$root/tb/cpu_dut_$cpu.vhd")
  for t in "${tests[@]}"; do
    files+=("$root/tb/$t.vhd")
  done

  # Run inside the run folder; GHDL keeps its compiled files there.
  # "|| exit $?" stops the script at the first failure and passes GHDL's
  # exit code on.
  cd "$run" || exit 1
  ghdl -a "${opts[@]}" "${files[@]}" || exit $?

  # Elaborate and run each test
  for t in "${tests[@]}"; do
    echo "===== $cpu : $t ====="
    ghdl -e "${opts[@]}" "$t" || exit $?
    ghdl -r "${opts[@]}" "$t" || exit $?
  done
done

exit 0