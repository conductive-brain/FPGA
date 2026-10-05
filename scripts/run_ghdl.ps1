# Runs the reset test for the hardwired CPU in GHDL.
# Use, from the project folder:
#   powershell -ExecutionPolicy Bypass -File scripts\run_ghdl.ps1
# Exit code: 0 = test passed, anything else = test failed.

# Project folder = the folder above this script's folder
$root = Split-Path -Parent $PSScriptRoot
$run  = "$root\sim_out\tb_reset_hw"

# Fresh run folder: delete the old one, make a new one
Remove-Item -Recurse -Force $run -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $run | Out-Null

# Intel's .mif reader crashes on lines with leading or trailing spaces
(Get-Content "$root\src\hw\external_memory.mif") | ForEach-Object { $_.Trim() } | Set-Content "$run\external_memory.mif"

# GHDL settings (PROJECT_GUIDE.md, section 4)
$opts = @('--std=08','-frelaxed','-fsynopsys',"-P$env:USERPROFILE\tools\intel_ghdl","-P$env:USERPROFILE\tools\uvvm_ghdl")

# Run inside the run folder; the ROM looks for the .mif there
Push-Location $run
ghdl -a @opts "$root\src\hw\sub_pack.vhd" "$root\src\hw\main_pack.vhd" "$root\src\hw\external_mem_altera.vhd" "$root\src\hw\vs_cpu_hw.vhd" "$root\tb\tb_reset_hw.vhd"
if ($LASTEXITCODE -eq 0) { ghdl -e @opts tb_reset_hw }
if ($LASTEXITCODE -eq 0) { ghdl -r @opts tb_reset_hw }
$code = $LASTEXITCODE
Pop-Location

exit $code