# hbnum: Released to Public Domain.
#
# Usage:
#   .\env\hbnum_env.ps1 tuning
#   .\env\hbnum_env.ps1 gate -DisableZig
#   .\env\hbnum_env.ps1 tuning -BenchFilter PERF_MOD_512D
#
# Presets clear per-run overrides so tests/benchmarks fall back to
# tests/hbnum_test.ini unless an explicit parameter below is provided.

[CmdletBinding()]
param(
   [Parameter(Position = 0)]
   [string] $Preset = "local",

   [string] $TestIni,
   [string] $TestProfile,

   [switch] $DisableZig,
   [string] $ZigRoot,
   [string] $ZigTarget = "x86_64-windows-gnu",
   [string] $ZigLibDir,

   [string] $BenchFilter,
   [switch] $BenchSkipPerf,
   [int] $BenchLoopMultiplier,
   [int] $BenchMinMs,
   [int] $BenchMaxLoops,

   [switch] $EnableTBig,
   [switch] $DisableTBig,

   [switch] $Clear,
   [switch] $EmitCmd,
   [switch] $Quiet
)

Set-StrictMode -Version 2.0

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

$knownVars = @(
   "HBNUM_TEST_INI",
   "HBNUM_TEST_PROFILE",
   "HBNUM_UNIT_GROUPS",
   "HBNUM_UNIT_MOD_FUZZ_SEED",
   "HBNUM_UNIT_MOD_FUZZ_DECIMAL_SEED",
   "HBNUM_UNIT_MOD_FUZZ_INT_LOOPS",
   "HBNUM_UNIT_MOD_FUZZ_DECIMAL_LOOPS",
   "HBNUM_ROBUST_SEED",
   "HBNUM_ROBUST_INT_LOOPS",
   "HBNUM_ROBUST_DECIMAL_LOOPS",
   "HBNUM_ROBUST_LARGE_LOOPS",
   "HBNUM_ROBUST_LIFECYCLE_LOOPS",
   "HBNUM_BENCH_FILTER",
   "HBNUM_BENCH_SKIP_PERF",
   "HBNUM_BENCH_LOOP_MULTIPLIER",
   "HBNUM_BENCH_MIN_MS",
   "HBNUM_BENCH_MAX_LOOPS",
   "HBNUM_TBIG_ENABLE",
   "HBNUM_TBIG_POWINT_LOOPS",
   "HBNUM_TBIG_MUL_LOOPS",
   "HBNUM_TBIG_MOD_LOOPS",
   "HBNUM_TBIG_GCD_LOOPS",
   "HBNUM_TBIG_SQRT_LOOPS",
   "HBNUM_TBIG_NTHROOT_LOOPS",
   "HBNUM_TBIG_LOG_LOOPS",
   "HBNUM_TBIG_LOG10_LOOPS",
   "HBNUM_TBIG_LN_LOOPS",
   "HBNUM_ZIG_ENABLE",
   "HB_ZIG_ROOT",
   "HB_ZIG_TARGET",
   "HB_ZIG_LIBDIR"
)

$overrideVars = $knownVars | Where-Object {
   $_ -notin @(
      "HBNUM_TEST_INI",
      "HBNUM_TEST_PROFILE",
      "HBNUM_ZIG_ENABLE",
      "HB_ZIG_ROOT",
      "HB_ZIG_TARGET",
      "HB_ZIG_LIBDIR"
   )
}

$settings = [ordered] @{}

function Add-HBEnvSetting {
   param(
      [Parameter(Mandatory = $true)]
      [string] $Name,
      [AllowNull()]
      [string] $Value
   )

   if ($null -eq $Value) {
      $Value = ""
   }

   $script:settings[$Name] = $Value
}

function Add-HBEnvClear {
   param(
      [Parameter(Mandatory = $true)]
      [string[]] $Names
   )

   foreach ($name in $Names) {
      Add-HBEnvSetting -Name $name -Value ""
   }
}

function ConvertTo-CmdSetLine {
   param(
      [Parameter(Mandatory = $true)]
      [string] $Name,
      [AllowNull()]
      [string] $Value
   )

   $escapedValue = if ($null -eq $Value) { "" } else { $Value.Replace('"', '\"') }
   return 'set "' + $Name + '=' + $escapedValue + '"'
}

if ($Clear) {
   Add-HBEnvClear -Names $knownVars
} else {
   $presetName = $Preset.Trim().ToLowerInvariant()
   $profileByPreset = @{
      "local"   = ""
      "default" = ""
      "gate"    = "gate"
      "smoke"   = "smoke"
      "tuning"  = "tuning"
   }

   if (-not $profileByPreset.ContainsKey($presetName)) {
      throw "Unknown HBNum environment preset '$Preset'. Use local, default, gate, smoke, or tuning."
   }

   Add-HBEnvClear -Names $overrideVars

   if (-not $PSBoundParameters.ContainsKey("TestIni")) {
      $TestIni = Join-Path $repoRoot "tests\hbnum_test.ini"
   }

   if (-not $PSBoundParameters.ContainsKey("TestProfile")) {
      $TestProfile = $profileByPreset[$presetName]
   }

   if (-not $PSBoundParameters.ContainsKey("ZigRoot")) {
      $ZigRoot = "C:\GitHub\naldodj-harbour-core"
   }

   if (-not $PSBoundParameters.ContainsKey("ZigLibDir")) {
      $ZigLibDir = Join-Path $ZigRoot "lib\win\mingw64"
   }

   Add-HBEnvSetting -Name "HBNUM_TEST_INI" -Value $TestIni
   Add-HBEnvSetting -Name "HBNUM_TEST_PROFILE" -Value $TestProfile
   Add-HBEnvSetting -Name "HBNUM_ZIG_ENABLE" -Value $(if ($DisableZig) { "0" } else { "1" })
   Add-HBEnvSetting -Name "HB_ZIG_ROOT" -Value $ZigRoot
   Add-HBEnvSetting -Name "HB_ZIG_TARGET" -Value $ZigTarget
   Add-HBEnvSetting -Name "HB_ZIG_LIBDIR" -Value $ZigLibDir

   if ($PSBoundParameters.ContainsKey("BenchFilter")) {
      Add-HBEnvSetting -Name "HBNUM_BENCH_FILTER" -Value $BenchFilter
   }
   if ($PSBoundParameters.ContainsKey("BenchSkipPerf")) {
      Add-HBEnvSetting -Name "HBNUM_BENCH_SKIP_PERF" -Value "1"
   }
   if ($PSBoundParameters.ContainsKey("BenchLoopMultiplier")) {
      Add-HBEnvSetting -Name "HBNUM_BENCH_LOOP_MULTIPLIER" -Value ([string] $BenchLoopMultiplier)
   }
   if ($PSBoundParameters.ContainsKey("BenchMinMs")) {
      Add-HBEnvSetting -Name "HBNUM_BENCH_MIN_MS" -Value ([string] $BenchMinMs)
   }
   if ($PSBoundParameters.ContainsKey("BenchMaxLoops")) {
      Add-HBEnvSetting -Name "HBNUM_BENCH_MAX_LOOPS" -Value ([string] $BenchMaxLoops)
   }

   if ($EnableTBig -and $DisableTBig) {
      throw "Use only one of -EnableTBig or -DisableTBig."
   }
   if ($EnableTBig) {
      Add-HBEnvSetting -Name "HBNUM_TBIG_ENABLE" -Value "1"
   }
   if ($DisableTBig) {
      Add-HBEnvSetting -Name "HBNUM_TBIG_ENABLE" -Value "0"
   }
}

if ($EmitCmd) {
   foreach ($entry in $settings.GetEnumerator()) {
      ConvertTo-CmdSetLine -Name $entry.Key -Value $entry.Value
   }
   exit 0
}

foreach ($entry in $settings.GetEnumerator()) {
   if ([string]::IsNullOrEmpty($entry.Value)) {
      Remove-Item -Path ("Env:" + $entry.Key) -ErrorAction SilentlyContinue
   } else {
      Set-Item -Path ("Env:" + $entry.Key) -Value $entry.Value
   }
}

if (-not $Quiet) {
   Write-Host "[HBNum] Environment preset: $Preset"
   foreach ($entry in $settings.GetEnumerator()) {
      $value = if ([string]::IsNullOrEmpty($entry.Value)) { "(cleared)" } else { $entry.Value }
      Write-Host ("[HBNum] {0}={1}" -f $entry.Key, $value)
   }
}
