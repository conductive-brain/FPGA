# Runs all GHDL tests.
# Use, from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\run_ghdl.ps1
# Exit code: 0 = all tests passed, anything else = a test failed.

# Project folder = the folder above this script's folder
$root = Split-Path -Parent $PSScriptRoot
$run  = "$root\sim_out\run"

# The tests, in the order they run
$tests = @('tb_reset_hw', 'tb_cpu_hw', 'tb_model_hw')

# Fresh run folder: delete the old one, make a new one
Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $run | Out-Null

# GHDL settings (PROJECT_GUIDE.md, section 4)
$opts = @('--std=08','-frelaxed',"-P$env:USERPROFILE\tools\uvvm_ghdl")

# Run inside the run folder; GHDL keeps its compiled files there
Push-Location $run

# Analyse every file once: CPU, simulation memory, tests
ghdl -a @opts "$root\src\hw\sub_pack.vhd" "$root\src\hw\main_pack.vhd" "$root\tb\mem_sim_pkg.vhd" "$root\tb\cpu_model_pkg.vhd" "$root\tb\external_mem_sim.vhd" "$root\src\hw\vs_cpu_hw.vhd" "$root\tb\tb_reset_hw.vhd" "$root\tb\tb_cpu_hw.vhd" "$root\tb\tb_model_hw.vhd"

# Elaborate and run each test. Stop at the first failure.
foreach ($t in $tests) {
  if ($LASTEXITCODE -eq 0) {
    Write-Host "===== $t ====="
    ghdl -e @opts $t
  }
  if ($LASTEXITCODE -eq 0) { ghdl -r @opts $t }
}
$code = $LASTEXITCODE
Pop-Location

exit $code