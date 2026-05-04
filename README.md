# HBNum

HBNum is an arbitrary-precision numeric library for the Harbour ecosystem.

This README is the project contract. Keep it accurate when code, build files,
tests, or validation rules change.

## Goals

- Provide a Harbour-first API backed by a C numeric engine.
- Keep arithmetic deterministic and exact unless a precision policy is explicit.
- Avoid floating-point arithmetic in HBNum calculations.
- Keep operations immutable-style: inputs are not mutated and results are new values.
- Make correctness, diagnostics, and performance measurable from repeatable tests.

## Non-Negotiable Rules

- Heavy arithmetic belongs in C.
- Harbour owns API shape, object lifecycle, context policy, and orchestration.
- Numbers use the mandatory HBNum hash layout documented below.
- No shared limb arrays between objects.
- No hidden default precision cap inside the numeric core.
- Approximation policy belongs to `HBNumContext` or to explicit method parameters.

## Numeric Model

Every HBNum value is represented as:

```harbour
{
   "nSign"  => -1 | 0 | 1,
   "nScale" => >= 0,
   "nUsed"  => >= 0,
   "aLimbs" => array of integers
}
```

| Field | Meaning |
| --- | --- |
| `nSign` | `-1` negative, `0` zero, `1` positive |
| `nScale` | Decimal scale |
| `nUsed` | Number of active limbs |
| `aLimbs` | Little-endian limb array |

The value is:

```txt
integer * 10^(-nScale)
```

Example:

```txt
"123.45" => integer 12345, nScale 2
```

The limb base is fixed at `2^30`:

```c
#define HBNUM_LIMB_BITS 30
#define HBNUM_BASE      (( HB_U32 ) 1073741824UL)
#define HBNUM_MASK      (( HB_U32 ) 1073741823UL)
```

Each limb must satisfy:

```txt
0 <= limb < HBNUM_BASE
```

## Core Invariants

- `nUsed == Len(aLimbs)`.
- No leading zero limbs, except the canonical zero value.
- Canonical zero is `nSign == 0`, `nScale == 0`, `nUsed == 0`, `aLimbs == {}`.
- Non-zero values must have `nSign` equal to `-1` or `1`.
- Every public operation must normalize the returned structure.
- Every public operation must return a new hash and must not mutate its inputs.

## Architecture

```txt
Harbour API and orchestration
        |
        v
C native numeric core
```

Harbour responsibilities:

- `HBNum` object lifecycle and public API.
- Operand coercion and result wrapping.
- `HBNumContext` precision policy.
- API grouping through operation helper classes.
- Test and benchmark orchestration.

C responsibilities:

- Limb arithmetic.
- Normalization and invariant enforcement.
- Hash parsing and hash rebuild.
- Carry, borrow, division, modulo, roots, logs, and number-theory primitives.
- Presentation formatting that must avoid binary floating-point conversion.
- Performance-critical loops.

Current source layout:

```txt
include/
  hbnum.h
  hbnum.ch
  hbnum_defs.ch
  hbnum_prg.h

src/hb/
  hbnum.prg
  hbnum_context.prg
  hbnum_compare_ops.prg
  hbnum_math_ops.prg
  hbnum_integer_ops.prg

src/c/
  hbnum_core.c
  hbnum_core_format.c
  hbnum_core_math.c
  hbnum_core_number_theory.c
  hbnum_core_integer_extra.c
  hbnum_native_internal.h

tests/
  test.prg
  bench_compare.prg
  robustness.prg
  hbnum_test_paths.prg
  test.hbp

hbp/
  hbnum*.hbp
hbc/
  hbnum*.hbc
hbm/
  hbnum*.hbm

mk/
  go64_*.bat
  tools/

tools/
  tbig_smoke.prg

lib/win/msvc64/
  hbnum.lib

exe/win/msvc64/
  hbnum_test.exe
  hbnum_bench.exe
  hbnum_bench_tbig.exe
  hbnum_robust.exe

log/win/msvc64/
  hbnum_tests.log
  hbnum_bench_compare.log
  hbnum_bench_compare.csv
  hbnum_robust.log
```

## Public API

`HBNum` currently exposes:

```harbour
CLASS HBNum
   METHOD New( xValue )
   METHOD FromString( cValue )
   METHOD FromInt( nValue )
   METHOD Clone()

   METHOD Add( xValue )
   METHOD Sub( xValue )
   METHOD Mul( xValue )
   METHOD Div( xValue, nPrecision )
   METHOD Mod( xValue )
   METHOD PowInt( nExp )

   METHOD Compare( xValue )
   METHOD Eq( xValue )
   METHOD Ne( xValue )
   METHOD Gt( xValue )
   METHOD Gte( xValue )
   METHOD Lt( xValue )
   METHOD Lte( xValue )
   METHOD Min( xValue )
   METHOD Max( xValue )

   METHOD Sqrt( nPrecision )
   METHOD NthRoot( nDegree, nPrecision )
   METHOD Log( xBase, nPrecision )
   METHOD Log10( nPrecision )
   METHOD Ln( nPrecision )

   METHOD Gcd( xValue )
   METHOD Lcm( xValue )
   METHOD Factorial()
   METHOD Fi()
   METHOD MillerRabin( xIterations )
   METHOD Randomize( xMin, xMax )
   METHOD Fibonacci()

   METHOD Round( nPrecision )
   METHOD Truncate( nPrecision )
   METHOD Floor( nPrecision )
   METHOD Ceiling( nPrecision )

   METHOD Abs()
   METHOD Neg()
   METHOD IsZero()
   METHOD Normalize()
   METHOD ToString()
   METHOD ToScientific( nSignificantDigits )
   METHOD ToEngineering( nSignificantDigits )

   METHOD SetContext( oContext )
   METHOD GetContext()
   METHOD SetPrecision( nPrecision )
   METHOD GetPrecision()
   METHOD SetRootPrecision( nPrecision )
   METHOD GetRootPrecision()
   METHOD SetLogPrecision( nPrecision )
   METHOD GetLogPrecision()
ENDCLASS
```

## Formatting and Conversion Toolkit

HBNum now has a dedicated C formatting layer in `src/c/hbnum_core_format.c`.
The first implemented methods are:

```harbour
HBNum():New( "12345" ):ToScientific()       // "1.2345E+4"
HBNum():New( "12345" ):ToEngineering()      // "12.345E+3"
HBNum():New( "999" ):ToScientific( 2 )      // "1.0E+3"
HBNum():New( "0.12" ):ToEngineering()       // "120E-3"
```

Formatting rules:

- `ToScientific()` emits one digit before the decimal separator and a base-10 exponent.
- `ToEngineering()` emits an exponent that is always a multiple of `3`.
- When `nSignificantDigits` is omitted, `NIL`, `0`, or negative, output is exact and canonical for display; non-significant trailing decimal zeros are trimmed.
- When `nSignificantDigits` is positive, output is rounded half-up to that many significant digits and padded with zeros when needed.
- Formatting is display-only. It does not mutate the source `HBNum` and does not use `double` or other binary floating-point conversion.

Planned extensions for this same area include grouped/fixed decimal formatting,
`NoRnd`-style display modes, and base conversions such as
`D2H/H2D/H2B/B2H/D2B/B2D`.

## Implementation Status

Updated: 2026-05-04.

Core arithmetic and model:

- [x] Base `2^30` limb model.
- [x] Hash structure and normalization.
- [x] Clone, parse, and string conversion.
- [x] Add, Sub, Mul, Div.
- [x] Exact terminating decimal division when precision is omitted.
- [x] Error on non-terminating division when no explicit/context precision exists.
- [x] Abs, Neg, IsZero.
- [x] No-mutation behavior covered by tests.

Formatting and conversion:

- [x] `ToScientific()` for exact scientific notation.
- [x] `ToScientific( nSignificantDigits )` with display-only half-up rounding.
- [x] `ToEngineering()` with exponent multiples of `3`.
- [x] `ToEngineering( nSignificantDigits )` with display-only half-up rounding.
- [ ] Grouped/fixed/custom decimal formatting.
- [ ] `NoRnd`-style display formatting.
- [ ] Conversion helpers such as `D2H/H2D/H2B/B2H/D2B/B2D`.

Comparison and decimal policy:

- [x] Compare, Eq, Ne, Gt, Gte, Lt, Lte.
- [x] Min and Max.
- [x] `HBNumContext` with precision, root precision, and log precision.
- [x] Round, Truncate, Floor, Ceiling.

Advanced math:

- [x] Mod.
- [x] Direct native modulo path using division remainder instead of `div -> mul -> sub`.
- [x] PowInt for non-negative integer exponents.
- [x] Sqrt with exact and precision-driven modes.
- [x] NthRoot with exact and precision-driven modes.
- [x] Log, Log10, and Ln with context-driven precision behavior.
- [ ] General `Pow` with negative exponent and precision policy.

Integer and number-theory tools:

- [x] GCD.
- [x] LCM.
- [x] Factorial.
- [x] Euler phi (`Fi`).
- [x] Miller-Rabin primality check.
- [x] Randomize.
- [x] Fibonacci sequence generation.

Testing and validation:

- [x] Unit test runner: `tests/test.prg`.
- [x] Test log output: `log/win/msvc64/hbnum_tests.log`.
- [x] Spinner feedback for long-running tests and benchmarks.
- [x] Mod fuzz tests in the normal test suite.
- [x] Robustness/property runner: `tests/robustness.prg`.
- [x] Robustness loop control through `HBNUM_ROBUST_*`.
- [x] INI profile loading through `tests/hbnum_test.ini`.
- [x] Unit group selection and mod fuzz loop control through profile/env settings.
- [x] Benchmark and accuracy runner: `tests/bench_compare.prg`.
- [x] CSV and log output for benchmark runs.
- [x] Comparative HBNum x tBigNumber build path.
- [x] Comparative tBigNumber build links the real Harbour MT VM; the old link stub was removed.
- [x] Harbour commit-check wrapper exists: `mk/go64_commit_check.bat`.
- [x] Local build-and-test validation gate: `mk/go64_gate.bat`.
- [ ] CI or pre-commit automation for the full validation flow.

Performance:

- [x] `Mod` optimized to avoid redundant quotient multiplication.
- [x] Single-limb divisor fast path in internal division/modulo helper.
- [ ] Division still uses bit-by-bit long division for multi-limb divisors.
- [ ] Replace multi-limb division with limb-estimated division.
- [ ] Clean up runtime-library warning `LNK4098`.

Porting and compatibility:

- [x] Core tBigNumber-compatible arithmetic subset covered by comparative tests.
- [x] Root/log comparative subset covered for selected vectors.
- [ ] Full tBigNumber inventory mapping is not complete.
- [ ] Full INI/profile-driven operand and regression-vector expansion is not complete.

## Build

The current supported local build uses Harbour `hbmk2` with MSVC64.

Prerequisites:

- Harbour MSVC64 distribution.
- Visual Studio 2022 C/C++ build tools.
- `vcvarsall.bat` available at:

```txt
%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat
```

The batch files currently expect:

```bat
SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
```

Build from `mk/`:

```bat
cd mk
go64_all.bat
go64_lib.bat
go64_test.bat
go64_bench.bat
go64_robust.bat
go64_gate.bat
```

`go64_all.bat` runs every other `.bat` file in `mk/` in name order, skips
itself and `go64_gate.bat`, and stops on the first failing script. If
`HBNUM_ZIG_ENABLE=1` is set before launching it, that also includes the opt-in
`go64_zig_*.bat` wrappers.

Run the local validation gate:

```bat
cd mk
go64_gate.bat
```

The gate defaults to `HBNUM_TEST_PROFILE=gate` when no profile is already set.
It builds the MSVC64 library and executables, runs unit tests, robustness tests,
selected HBNum benchmark coverage, comparative tBigNumber smoke coverage, and
`go64_commit_check.bat`. Set `HBNUM_GATE_SKIP_TBIG=1` to skip the comparative
tBigNumber build/run when that external checkout is not available.

Build the comparative tBigNumber benchmark:

```bat
cd mk
go64_bench_tbig.bat
```

Experimental Zig builds:

```bat
cd mk
go64_zig_lib.bat
go64_zig_test.bat
go64_zig_robust.bat
go64_zig_bench.bat
go64_zig_bench_tbig.bat
```

To rebuild the external `tBigNumber` library with Zig before the comparative
benchmark target, either run the helper directly:

```bat
cd mk
call tools\go64_zig_tbig_lib.bat
```

or let the wrapper rebuild it first:

```bat
cd mk
go64_zig_bench_tbig.bat
```

The Zig path is intentionally opt-in for `go64_all.bat`. The direct
`go64_zig_*.bat` wrappers set `HBNUM_ZIG_ENABLE=1` internally when that
variable is not already defined, and `go64_zig_bench_tbig.bat` also defaults
`HBNUM_ZIG_TBIG_ENABLE=1` so it refreshes the external `tBigNumber` library
before linking unless you override it. They use `zig.exe` from `PATH` and a
Harbour checkout whose `utils/hbmk2/hbmk2.prg` supports `-comp=zig`. By
default they expect that checkout at:

```txt
C:\GitHub\naldodj-harbour-core
```

Override it with:

```bat
set HB_ZIG_ROOT=C:\path\to\harbour-core
set HB_ZIG_TARGET=x86_64-windows-gnu
set HB_ZIG_LIBDIR=C:\path\to\harbour-core\lib\win\mingw64
set TBIG_ZIG_ROOT=C:\path\to\tBigNumber
set TBIG_ZIG_OUTDIR=C:\path\to\tBigNumber\lib\win\mingw64
```

The current Zig wrappers support the HBNum static library plus the native
`hbnum_test`, `hbnum_robust`, `hbnum_bench`, and `hbnum_bench_tbig`
executables. The comparative `hbnum_bench_tbig` target needs an external
tBigNumber library refreshed into `lib/win/mingw64`.

Expected outputs:

```txt
lib/win/zig/libhbnum.a
exe/win/zig/hbnum_test.exe
exe/win/zig/hbnum_robust.exe
exe/win/zig/hbnum_bench.exe
exe/win/zig/hbnum_bench_tbig.exe
lib/win/msvc64/hbnum.lib
exe/win/msvc64/hbnum_test.exe
exe/win/msvc64/hbnum_bench.exe
exe/win/msvc64/hbnum_bench_tbig.exe
exe/win/msvc64/hbnum_robust.exe
```

## Test Execution

Run the normal test suite:

```bat
exe\win\msvc64\hbnum_test.exe
```

Run HBNum-only benchmark and accuracy checks:

```bat
exe\win\msvc64\hbnum_bench.exe
```

Run comparative benchmark and accuracy checks:

```bat
exe\win\msvc64\hbnum_bench_tbig.exe
```

Run robustness/property/stress tests:

```bat
exe\win\msvc64\hbnum_robust.exe
```

Output logs:

```txt
log/win/msvc64/hbnum_tests.log
log/win/msvc64/hbnum_bench_compare.log
log/win/msvc64/hbnum_bench_compare.csv
log/win/msvc64/hbnum_robust.log
```

## Runtime Test Knobs

The project already supports environment-driven test and benchmark control.

Shared profile loader:

| Variable | Purpose |
| --- | --- |
| `HBNUM_TEST_INI` | Overrides the default profile file path (`tests/hbnum_test.ini`) |
| `HBNUM_TEST_PROFILE` | Selects profile override sections such as `profile.gate.*` or `profile.smoke.*` |

Unit runner:

| Variable | Purpose |
| --- | --- |
| `HBNUM_UNIT_GROUPS` | Overrides `[unit] groups`; comma/semicolon/pipe separated |
| `HBNUM_UNIT_MOD_FUZZ_SEED` | Overrides `[unit] mod_fuzz_seed` |
| `HBNUM_UNIT_MOD_FUZZ_DECIMAL_SEED` | Overrides `[unit] mod_fuzz_decimal_seed` |
| `HBNUM_UNIT_MOD_FUZZ_INT_LOOPS` | Overrides `[unit] mod_fuzz_int_loops` |
| `HBNUM_UNIT_MOD_FUZZ_DECIMAL_LOOPS` | Overrides `[unit] mod_fuzz_decimal_loops` |

Benchmark runner:

| Variable | Purpose |
| --- | --- |
| `HBNUM_BENCH_FILTER` | Runs only cases matching the filter text |
| `HBNUM_BENCH_SKIP_PERF` | Skips performance loops when truthy |
| `HBNUM_TBIG_ENABLE` | Enables/disables comparative tBigNumber sections in comparative builds |
| `HBNUM_TBIG_<OP>_LOOPS` | Overrides `[compare.tbig]` caps, for example `HBNUM_TBIG_MOD_LOOPS` |

Example:

```bat
set HBNUM_BENCH_FILTER=PERF_MOD_512D
exe\win\msvc64\hbnum_bench.exe
```

Robustness runner:

| Variable | Purpose |
| --- | --- |
| `HBNUM_ROBUST_SEED` | Deterministic seed |
| `HBNUM_ROBUST_INT_LOOPS` | Integer oracle loop count |
| `HBNUM_ROBUST_DECIMAL_LOOPS` | Decimal oracle loop count |
| `HBNUM_ROBUST_LARGE_LOOPS` | Large constructed stress loop count |
| `HBNUM_ROBUST_LIFECYCLE_LOOPS` | Lifecycle/allocation pressure loop count |

Example:

```bat
set HBNUM_ROBUST_SEED=20260421
set HBNUM_ROBUST_INT_LOOPS=1000
set HBNUM_ROBUST_DECIMAL_LOOPS=1000
set HBNUM_ROBUST_LARGE_LOOPS=250
set HBNUM_ROBUST_LIFECYCLE_LOOPS=5000
exe\win\msvc64\hbnum_robust.exe
```

Any robustness loop count can be set to `0` to isolate another suite.

## INI-Driven Test Profiles

The existing environment variables remain useful for quick local debugging, but
repeatable test campaigns now have a shared INI profile file similar in purpose
to `tBigNumber/tBigNtst.ini`.

Default file:

```txt
tests/hbnum_test.ini
```

Implemented responsibilities:

- Select unit test groups: `add`, `sub`, `mul`, `div`, `rounding`,
  `root_log`, `domain_policy`, `compare`, `format`, `mod`, `powint`,
  `number_theory`, `random`, `tbigntst`.
- Configure seeds and loop counts.
- Configure tBigNumber smoke caps for operations that are known to be slow.
- Keep command-line/env overrides for quick local debugging.
- Provide named overrides such as `gate` and `smoke` through
  `HBNUM_TEST_PROFILE`.

Still planned for this area:

- Select whole suites from a single orchestrator.
- Configure operand ranges and digit sizes.
- Configure explicit values for one-off regression vectors.

Sketch:

```ini
[run]
suites=unit,robust,bench
seed=20260423

[unit]
groups=mod,div,number_theory
mod_fuzz_int_loops=400
mod_fuzz_decimal_loops=400

[robustness]
int_loops=1000
decimal_loops=1000
large_loops=250
lifecycle_loops=5000

[benchmark]
filter=PERF_MOD_512D
skip_perf=false

[compare.tbig]
enabled=true
mod_loops=5
sqrt_loops=1
nthroot_loops=1
```

Status: profile loading is implemented for the unit, robustness, benchmark, and
comparative benchmark runners. Environment variables still take precedence over
INI values.

## tBigNumber Comparative Mode

Comparative mode requires an external `tBigNumber` checkout. HBNum supports
both of these local pin files:

```txt
C:/GitHub/tBigNumber/include/
C:/GitHub/tBigNumber/lib/win/mingw64/lib_tbigNumber.a
C:/GitHub/tBigNumber/lib/win/msvc64/_tbigNumber_msvc.lib
```

HBNum links it through:

```txt
hbc/hbnum_tbig_mingw64.hbc
hbc/hbnum_tbig_msvc.hbc
```

Important notes:

- `hbp/hbnum_bench_tbig.hbp` uses `-mt` because `tBigNumber` requests `HB_MT`.
- `tests/tbig_link_stubs.prg` was removed; comparative mode should link the real MT runtime.
- `C:/GitHub/tBigNumber/hbp/tbigntst_msvc.hbp` is the external standalone test app build.
- `go64_zig_bench_tbig.bat` expects the MinGW64-style `tBigNumber` library tree.
- `mk/tools/go64_zig_tbig_lib.bat` rebuilds `C:/GitHub/tBigNumber/lib/win/mingw64/lib_tbigNumber.a` using Zig instead of MinGW.
- The helper forces `-x c++` for Zig because `tBigNumber` embeds C++ `BEGINDUMP` code in a generated `.c` unit.
- `C:/GitHub/tBigNumber/src/hb/c/tbignumber.c` should carry the normalized `memcmp()` fix upstream so the Zig helper no longer needs a local compatibility source.
- `C:/GitHub/tBigNumber/mk/hbmk.hbm` affects the external tBigNumber build when that library is rebuilt; it is not auto-loaded by HBNum's `hbmk2` invocation.

## Validation Notes

Current validation coverage includes:

- Deterministic unit tests for all public operations listed in the implemented status.
- Mod fuzz tests for integer and decimal operands.
- Robustness/property tests with integer, decimal, large constructed, and lifecycle scenarios.
- HBNum-only benchmark and accuracy checks.
- Comparative HBNum x tBigNumber accuracy checks for the shared-compatible subset.
- Application Verifier smoke validation has been used for heap/handle/memory/leak checks.

Application Verifier can legitimately export no log file when no verifier events
are recorded for a run.

## Coding Standard

Project-owned code and build files should contain:

```txt
hbnum: Released to Public Domain.
```

Repository text-file rules:

- Use CRLF for project text files unless a specific tool requires otherwise.
- Keep final newline at end of file.
- Remove trailing whitespace.
- Avoid mixed line endings.
- Keep filenames ASCII-7.

Useful checks:

```powershell
rg -n --pcre2 "[ \t]+$" src include tests mk README.md ChangeLog.txt
```

```bat
cd mk
go64_commit_check.bat
```

## Next Steps

Implementation sequence:

1. Extend `tests/hbnum_test.ini` profile coverage.
   - Add operand ranges, digit-size controls, and explicit regression vectors.
   - Add an orchestrator that can select whole suites from `[run] suites`.

2. Add CI or pre-commit automation for the validation flow.
   - Reuse `mk/go64_gate.bat` where practical.
   - Keep the gate's final PASS/FAIL status aligned with the log files.

3. Replace multi-limb bit-by-bit division with limb-estimated division.
   - The current multi-limb path in `hbnum_mag_divmod()` is correct but intentionally simple.
   - A limb-estimated algorithm should improve `Div`, `Mod`, `GCD`, `LCM`, `PowMod`, `MillerRabin`, roots, and logs.
   - Keep the current single-limb fast path and add focused regression vectors before replacing the multi-limb path.

4. Rebenchmark and tune division-dependent operations.
   - Compare MSVC64 and Zig results before and after the division rewrite.
   - Track `PERF_MOD_512D`, `PERF_GCD_240D`, `PERF_LN_10P200`, root/log cases, and comparative tBigNumber cases.
   - Update benchmark loop counts only when the measurements remain stable and useful.

5. Expand the tBigNumber comparative matrix.
   - Map more of the external `tBigNtst` inventory into HBNum tests.
   - Use safe caps for very slow tBigNumber operations, especially large `Mod` and `NthRoot` cases.
   - Keep comparative failures clearly attributable to HBNum, tBigNumber, or build/link configuration.

6. Investigate and clean up `LNK4098` runtime-library warnings.
   - Audit MSVC runtime flags in `.hbp` and `.hbc` files.
   - Keep the final MSVC build warning profile intentional and documented.

7. Add general `Pow` with negative exponent support.
   - Define precision/context policy before exposing the API.
   - Reuse existing exact `PowInt` behavior for non-negative integer exponents.

8. Expand the formatting/conversion toolkit.
   - Add grouped/fixed/custom output.
   - Add `NoRnd`-style display behavior.
   - Add base conversion helpers such as `D2H/H2D/H2B/B2H/D2B/B2D`.

9. Add optional cross-tool memory validation.
   - Keep Application Verifier-compatible workflows.
   - Add additional tooling only when it is locally available and repeatable.

## README Maintenance

Update this README whenever any of these change:

- Public API.
- Numeric representation or invariants.
- Build files or build commands.
- Test/benchmark/robustness runners.
- tBigNumber integration.
- Completed roadmap items.
- Known limitations and next steps.

Code changes without README status updates are incomplete work for this project.

## Vision

HBNum should behave like a native Harbour numeric type:

```txt
Fast. Deterministic. Predictable.
```

No magic. Correctness first, performance always measured.
