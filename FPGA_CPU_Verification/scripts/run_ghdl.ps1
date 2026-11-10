# Runs all GHDL tests on every CPU version.
# Use, from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\run_ghdl.ps1
# Exit code: 0 = all tests passed, anything else = a test failed.

# Project folder = the folder above this script's folder
$root = Split-Path -Parent $PSScriptRoot

# GHDL settings (README.md, "Running the tests")
$opts = @('--std=08','-frelaxed',"-P$env:USERPROFILE\tools\uvvm_ghdl")

# The tests, in the order they run. Each one is tb\<name>.vhd
$tests = @('tb_reset', 'tb_cpu', 'tb_model')

# The CPU versions and their design files. Each one also has a wrapper,
# tb\cpu_dut_<name>.vhd, that the tests connect to.
$cpus = [ordered]@{
  'hw'    = @("$root\src\hw\sub_pack.vhd", "$root\src\hw\main_pack.vhd", "$root\src\hw\vs_cpu_hw.vhd")
  'micro' = @("$root\src\micro\sub_pack.vhd", "$root\src\micro\main_pack.vhd", "$root\tb\rom_microp_sim.vhd", "$root\src\micro\vs_cpu.vhd")
}

foreach ($cpu in $cpus.Keys) {
  Write-Host "########## CPU: $cpu ##########"

  # Fresh run folder for this CPU: delete the old one, make a new one
  $run = "$root\sim_out\run_$cpu"
  Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force $run | Out-Null

  # The micro version's ROM model (tb\rom_microp_sim.vhd) reads microcode.mif
  # from the run folder
  if (Test-Path "$root\src\$cpu\microcode.mif") { Copy-Item "$root\src\$cpu\microcode.mif" $run }
  # All files, in the order GHDL needs them: simulation memory and model,
  # the CPU, its wrapper, then the tests
  $files  = @("$root\tb\mem_sim_pkg.vhd", "$root\tb\external_mem_sim.vhd", "$root\tb\cpu_model_pkg.vhd")
  $files += $cpus[$cpu]
  $files += "$root\tb\cpu_dut_$cpu.vhd"
  $files += $tests | ForEach-Object { "$root\tb\$_.vhd" }

  # Run inside the run folder; GHDL keeps its compiled files there
  Push-Location $run
  ghdl -a @opts @files

  # Elaborate and run each test. Stop at the first failure.
  foreach ($t in $tests) {
    if ($LASTEXITCODE -eq 0) {
      Write-Host "===== $cpu : $t ====="
      ghdl -e @opts $t
    }
    if ($LASTEXITCODE -eq 0) { ghdl -r @opts $t }
  }
  $code = $LASTEXITCODE
  Pop-Location

  if ($code -ne 0) { exit $code }
}

exit 0