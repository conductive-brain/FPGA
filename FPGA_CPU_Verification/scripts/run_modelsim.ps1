# Runs all tests on every CPU version in ModelSim (Intel FPGA Starter Edition,
# comes with Quartus Prime Lite 18.1). Same tests as run_ghdl.ps1.
# Use, from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\run_modelsim.ps1
# Exit code: 0 = all tests passed, 1 = a test failed.
# ModelSim exits with 0 even when a test fails, so this script decides from
# each test's output: pass only if it contains "Simulation SUCCESS" and no
# "ERROR #".

# Project folder = the folder above this script's folder
$root = Split-Path -Parent $PSScriptRoot

# ModelSim and UVVM. The UVVM source is compiled for ModelSim once, into $uvvm_lib.
$msim     = "C:\intelFPGA_lite\18.1\modelsim_ase\win32aloem"
$uvvm_src = "$env:USERPROFILE\tools\uvvm\uvvm_util"
$uvvm_lib = "$env:USERPROFILE\tools\uvvm_modelsim\uvvm_util"

# The tests and the CPU versions: the same lists as in run_ghdl.ps1
$tests = @('tb_reset', 'tb_cpu', 'tb_model')
$cpus = [ordered]@{
  'hw'    = @("$root\src\hw\sub_pack.vhd", "$root\src\hw\main_pack.vhd", "$root\src\hw\vs_cpu_hw.vhd")
  'micro' = @("$root\src\micro\sub_pack.vhd", "$root\src\micro\main_pack.vhd", "$root\tb\rom_microp_sim.vhd", "$root\src\micro\vs_cpu.vhd")
}

# Compile UVVM's utility library the first time only
if (-not (Test-Path "$uvvm_lib\_info")) {
  Write-Host "Compiling uvvm_util for ModelSim into $uvvm_lib (first run only)"
  New-Item -ItemType Directory -Force (Split-Path -Parent $uvvm_lib) | Out-Null
  & "$msim\vlib.exe" $uvvm_lib | Out-Null
  # compile_order.txt lists the source files in the order they must be compiled
  $order = Get-Content "$uvvm_src\script\compile_order.txt" | Where-Object { $_ -and -not $_.StartsWith('#') }
  foreach ($f in $order) {
    & "$msim\vcom.exe" -2008 -quiet -work $uvvm_lib "$uvvm_src\script\$f"
    if ($LASTEXITCODE -ne 0) { Write-Host "uvvm_util compile failed at $f"; exit 1 }
  }
}

foreach ($cpu in $cpus.Keys) {
  Write-Host "########## CPU: $cpu ##########"

  # Fresh run folder for this CPU
  $run = "$root\sim_out\msim_$cpu"
  Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force $run | Out-Null
  if (Test-Path "$root\src\$cpu\microcode.mif") { Copy-Item "$root\src\$cpu\microcode.mif" $run }
  Push-Location $run

  # A work library for this CPU, and where to find uvvm_util
  & "$msim\vlib.exe" work | Out-Null
  & "$msim\vmap.exe" uvvm_util $uvvm_lib | Out-Null

  # Compile: simulation memory and model, the CPU, its wrapper, then the tests
  $files  = @("$root\tb\mem_sim_pkg.vhd", "$root\tb\external_mem_sim.vhd", "$root\tb\cpu_model_pkg.vhd")
  $files += $cpus[$cpu]
  $files += "$root\tb\cpu_dut_$cpu.vhd"
  $files += $tests | ForEach-Object { "$root\tb\$_.vhd" }
  & "$msim\vcom.exe" -2008 -quiet @files
  if ($LASTEXITCODE -ne 0) { Pop-Location; exit 1 }

  # Run each test in batch mode (-c), keep its output in <test>.log, and
  # decide pass or fail from that output. Stop at the first failure.
  foreach ($t in $tests) {
    Write-Host "===== $cpu : $t ====="
    & "$msim\vsim.exe" -c -quiet $t -do "run -all; quit -f" | Tee-Object -FilePath "$t.log"
    $log = Get-Content "$t.log" -Raw
    if (($log -notmatch 'Simulation SUCCESS') -or ($log -match 'ERROR #')) {
      Write-Host "FAILED: $cpu : $t (see sim_out\msim_$cpu\$t.log)"
      Pop-Location
      exit 1
    }
  }
  Pop-Location
}

Write-Host "All ModelSim tests passed"
exit 0
