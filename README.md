# HBNumHBNum is an arbitrary precision numeric library designed for the Harbour ecosystem.
> ⚠️ This document is the SINGLE SOURCE OF TRUTH.
> > Any implementation MUST strictly follow these rules.

> > ## 1. SYSTEM OVERVIEWHBNum is:
> > > A **C-based numeric engine with a Harbour interface**Execution model:Harbour → orchestrationC       → computation
> > ### HARD RULEIF heavy math is implemented in Harbour → WRONG

> > ## 2. DESIGN PRINCIPLES- Harbour-first API (interface only)- ALL heavy computation MUST be in C- Arbitrary precision (memory-bound)- No hard-coded precision caps inside HBNum- Precision/approximation policy belongs to HBNumContext- Immutable-style operations- Deterministic arithmetic (no floating point)- Extensible architecture

> > ## 3. DATA STRUCTURE (MANDATORY)Every number MUST follow EXACTLY this structure:
```harbour
{
   "nSign"  => -1 | 0 | 1,
   "nScale" => >= 0,
   "nUsed"  => >= 0,
   "aLimbs" => array of integers
}
```
## 3.1 

|Field Rules| Field Rule                            |
| --------- | ------------------------------------- |
| nSign     | -1 (negative), 0 (zero), 1 (positive) |
| nScale    | decimal precision                     |
| nUsed     | number of used limbs                  |
| aLimbs    | little-endian                         |

## 3.2 Limb RulesBase MUST be:

```c#define HBNUM_BASE ((HB_U32)1073741824UL) // 2^30```

Each limb MUST satisfy:
```bash0 <= limb < HBNUM_BASE```

## 4. NUMERIC MODELRepresentation:
```bashvalue = integer * 10^(-nScale)```
Example:
```bash"123.45" →aLimbs = [12345]nScale = 2```

## 5. CORE INVARIANTS (CRITICAL)These MUST ALWAYS hold:- nUsed == len(aLimbs)- No leading zero limbs (except zero)- Zero representation:
```harbournSign = 0nUsed = 0aLimbs = {}```
- No shared memory between objects- All operations return NEW structures

## 6. OPERATION CONTRACT (MANDATORY)Every operation MUST:1. Receive TWO hashes2. NEVER mutate inputs3. Return NEW hash4. Normalize result5. Enforce invariants

## 7. NORMALIZATION RULESNormalization MUST:- Remove leading zero limbs- Adjust nUsed- Fix sign for zero- Ensure invariant compliance

## 8. ARCHITECTURE

```bash
Harbour Layer (API)
        ↓
C Core (Engine)
```

Current modular layout (started in this iteration):

```bash
Harbour
  - HBNum (core object lifecycle + delegation)
  - HBNumContext (precision/approximation policy for decimal operations)
  - HBNumCompareOps (relational/comparison helpers)
  - HBNumMathOps (modular integer-math helpers)
  - HBNumIntegerOps (number-theory integer helpers)

C
  - hbnum_core.c      (core arithmetic + parse/hash bridge)
  - hbnum_core_math.c (mod + integer power extension)
  - hbnum_core_number_theory.c (gcd + lcm extension)
```

### 8.1 Harbour Responsibilities- Input normalization- Object lifecycle- Delegation to C- Result wrapping
### 8.2 C Responsibilities- Arithmetic operations- Carry / borrow logic- Limb manipulation- Normalization- Performance-critical logic
## 9. C IMPLEMENTATION RULES (STRICT)
### MUST- Use HB_FUNC- Use PHB_ITEM- Use hb_array*, hb_hash*- Use hb_item*- Use hb_ret*- Use hb_xgrab / hb_xfree- Prefer stack allocation when possible
### MUST NOT- malloc inside loops- realloc inside loops- floating point usage- pointer sharing between objects- Harbour-based arithmetic loops
## 10. HARBOUR API (REFERENCE)
```harbour
CLASS HBNum
   DATA hbNum
   DATA oContext
   METHOD New(xValue)
   METHOD FromString(cValue)
   METHOD FromInt(nValue)
   METHOD Clone()
   METHOD Add(xValue)
   METHOD Sub(xValue)
   METHOD Mul(xValue)
   METHOD Div(xValue, nPrecision)
   METHOD Compare(xValue)
   METHOD Eq(xValue)
   METHOD Ne(xValue)
   METHOD Gt(xValue)
   METHOD Gte(xValue)
   METHOD Lt(xValue)
   METHOD Lte(xValue)
   METHOD Min(xValue)
   METHOD Max(xValue)
   METHOD Mod(xValue)
   METHOD PowInt(nExp)
   METHOD Gcd(xValue)
   METHOD Lcm(xValue)
   METHOD Round(nPrecision)
   METHOD Truncate(nPrecision)
   METHOD Floor(nPrecision)
   METHOD Ceiling(nPrecision)

   METHOD Abs()
   METHOD Neg()
   METHOD IsZero()
   METHOD Normalize()
   METHOD ToString()
   METHOD SetContext(oContext)
   METHOD GetContext()
   METHOD SetPrecision(nPrecision)
   METHOD GetPrecision()
   METHOD SetRootPrecision(nPrecision)
   METHOD GetRootPrecision()
   METHOD SetLogPrecision(nPrecision)
   METHOD GetLogPrecision()
ENDCLASS

CLASS HBNumContext
   DATA nPrecision
   DATA nRootPrecision
   DATA nLogPrecision
ENDCLASS
```
## 11. IMPLEMENTATION CHECKLIST (FOR AI)

Live status (must be updated on each implementation iteration):

- [x] Uses base 2^30
- [x] Does NOT mutate inputs
- [x] Returns new structure
- [x] Correct carry/borrow handling (Add/Sub)
- [x] No leading zeros after normalization
- [x] Invariants preserved in normalize + hash rebuild
- [x] Initial module split in C (`hbnum_core.c` + `hbnum_core_math.c`)
- [x] Initial operation classes in Harbour (`HBNumCompareOps` + `HBNumMathOps` + `HBNumIntegerOps`)
- [x] Compare helpers exposed (`Eq/Ne/Gt/Gte/Lt/Lte/Min/Max`)
- [x] Mod operation implemented (`HBNUM_CORE_MOD`)
- [x] Integer power implemented (`HBNUM_CORE_POWINT`)
- [x] Number-theory class added in Harbour (`HBNumIntegerOps`)
- [x] Number-theory C module added (`hbnum_core_number_theory.c`)
- [x] GCD implemented (`HBNUM_CORE_GCD`)
- [x] LCM implemented (`HBNUM_CORE_LCM`)
- [x] Precision context added in Harbour (`HBNumContext`)
- [x] `HBNum` no longer imposes hard-coded default precision caps
- [x] `Div()` auto-resolves exact terminating decimals when precision is omitted
- [x] `Div()` fails fast on non-terminating decimals unless explicit/context precision is available
- [x] Explicit decimal behavior toolkit added (`Round/Truncate/Floor/Ceiling`)
- [x] Benchmark/accuracy harness created (`tests/bench_compare.prg`)
- [x] CSV + LOG outputs created for benchmark runs
- [x] Dedicated benchmark build flow created (`mk/hbnum_bench*.hbp`)
- [x] Compare edge-case tests expanded (sign/scale/zero matrix)
- [x] Mod edge-case tests expanded (scale + divisor sign permutations)
- [x] PowInt edge-case tests expanded (decimal base + even negative base + zero base)
- [x] GCD/LCM edge-case tests expanded (very large operands + co-prime stress)
- [x] Shared benchmark accuracy vectors expanded (decimal/sign/large integer cases)
- [x] Comparative run validated with expanded shared-compatible vector set in `hbnum_bench_tbig.exe`
- [x] Property/randomized robustness suite added (`tests/robustness.prg`)
- [x] Dedicated robustness build flow created (`mk/hbnum_robust*.hbp`, `mk/go64_robust.bat`)
- [x] Stress/fuzz-style large-limb and lifecycle coverage validated in `hbnum_robust.exe`
- [x] Memory safety smoke validation executed with Application Verifier (`Heaps/Handles/Memory/Leak`)

Notes:

- C core uses `HB_U64` for carry/borrow intermediates.
- All operations exposed to Harbour return NEW hashes.
- C exports use `HBNUM_CORE_*` namespace to avoid method-name collisions in Harbour.
- `HBNum` growth is memory-bound and does not rely on a built-in default decimal precision cap.
- `HBNumContext` is the policy layer for approximate operations and precision-sensitive families.
- With `HBNumContext:nPrecision == NIL`, `Div()` returns exact terminating decimals and raises on non-terminating decimal expansions.
- `hbnum_robust.exe` supports env-driven loop profiles via `HBNUM_ROBUST_*`.
- Application Verifier export can legitimately return "no valid log file" when no verifier events are recorded for the run.
- Cross-tool memory analysis beyond Application Verifier remains optional future hardening when additional tooling is available.

## 12. PERFORMANCE RULES- Prefer stack over heap- Minimize allocations- Avoid copying arrays- Avoid dynamic resizing in loops- Optimize memory locality

## 13. FORBIDDEN PRACTICES- Floating point operations- Harbour loops for arithmetic- String-based math- Shared limb arrays- Premature optimization

## 14. DEVELOPMENT ORDERImplement in this sequence:1. Normalize2. Compare3. Add / Sub4. Mul5. Div

## 15. TEST CONTRACT (MANDATORY)> Every implementation MUST include test cases.
### 15.1 Test RequirementsEach operation MUST include:- Simple case- Carry / borrow case- Different sizes- Negative values- Zero handling- Extreme values
### 15.2 Test Format
```harbourFUNCTION Test_Add_Simple()   LOCAL oA := HBNum():FromString("2")   LOCAL oB := HBNum():FromString("3")   LOCAL oR := oA:Add(oB)   RETURN oR:ToString() == "5"```

### 15.3 Mandatory ADD Tests
```harbour
// carry
"999999999" + "1" = "1000000000"
// different size"123" + "999999999" = "1000000122"// negative"-10" + "5" = "-5"// zero"0" + "123" = "123"
```
---

### 15.3.1 Mandatory SUB Tests

```harbour
// simple
"5" - "3" = "2"

// borrow (limb)
hb_ntos(HBNUM_BASE) - "1" = hb_ntos(HBNUM_BASE - 1)

// negative result
"5" - "10" = "-5"

// zero handling
"0" - "123" = "-123"
```

---

### 15.3.2 Mandatory MUL Tests

```harbour
// simple
"2" * "3" = "6"

// carry-like growth
hb_ntos(HBNUM_BASE - 1) * "2" = hb_ntos((HBNUM_BASE - 1) * 2)

// different size
"123" * "999999999" = "122999999877"

// zero handling
"0" * "123" = "0"
```

---

### 15.3.3 Mandatory DIV Tests

```harbour
// exact terminating decimal without explicit precision/context
"1" / "8" = "0.125"

// simple exact integer without explicit precision/context
"10" / "2" = "5"

// truncation with explicit policy
"7" / "2" (precision 0) = "3"

// negative with explicit policy
"-10" / "4" (precision 0) = "-2"

// non-terminating decimal requires explicit precision/context
"1" / "3" (no precision/context) => error
```

---

### 15.3.4 Mandatory Compare/Mod/PowInt Tests

```harbour
// compare
"123.45" == "123.450"  => .T.
"-7" < "3"             => .T.

// min/max
Min("12.5","12.49")    => "12.49"
Max("12.5","12.49")    => "12.5"

// modulo
"10" mod "3"           => "1"
"-10" mod "3"          => "-1"

// integer power
"2" PowInt 10          => "1024"
"999" PowInt 0         => "1"
"-2" PowInt 3          => "-8"
```

---

### 15.3.5 Mandatory GCD/LCM Tests

```harbour
// gcd
Gcd("48","18")         => "6"
Gcd("-48","18")        => "6"
Gcd("0","18")          => "18"

// lcm
Lcm("21","6")          => "42"
Lcm("-21","6")         => "42"
Lcm("0","9")           => "0"
```

---

### 15.4 Internal Structure Validation

```harbour
FUNCTION Test_Add_Internal()
   LOCAL oA := HBNum():FromString( hb_ntos( HBNUM_BASE - 1 ) )
   LOCAL oB := HBNum():FromString("1")
   LOCAL oR := oA:Add(oB)

   RETURN ;
      oR:hbNum["nUsed"] > 1 .AND. ;
      oR:hbNum["nSign"] == 1```---### 15.5 Property-Based Tests```harbourFUNCTION Test_Add_Commutative()   LOCAL oA := HBNum():FromString("123456")   LOCAL oB := HBNum():FromString("789")   RETURN ;      oA:Add(oB):ToString() == ;      oB:Add(oA):ToString()```---### 15.6 C-Level Testing (RECOMMENDED)
Expose debug/test functions in C:```cHB_FUNC( HB_NUM_TEST_ADD )```Purpose:- Validate internal logic directly
- Avoid Harbour masking errors
- Inspect limb-level correctness

---

### 15.7 Test Output Trace (Current)

Test runner prints:

- test status (`[PASS]` / `[FAIL]`)
- operation executed
- expected value
- actual value

Additionally, tests now persist a detailed log file using LOGRDD-style flow:

- `INIT LOG ON FILE` / `SET LOG STYLE` / `LOG ... PRIORITY ...` / `CLOSE LOG`
- log file name: `hbnum_tests.log`
- default location: executable directory + `log/`, resolved from `hb_ProgName()` (for `mk/go64_test.bat`, this is `mk/msvc64/log/`)

This format is mandatory for faster diagnostics during iterative development.

---

### 15.8 Comparative Accuracy/Performance (HBNum x tBigNumber)

A dedicated runner now exists in:

- `tests/bench_compare.prg`

Outputs generated by this runner:

- `mk/msvc64/log/hbnum_bench_compare.log` (detailed execution trace)
- `mk/msvc64/log/hbnum_bench_compare.csv` (structured results for analysis)

Execution modes:

1. HBNum-only benchmark mode:
- build with `mk/hbnum_bench.hbp`
- validates HBNum accuracy vectors and performance baselines

2. Comparative mode (HBNum vs tBigNumber):
- build with `mk/hbnum_bench_tbig.hbp`
- compares canonicalized outputs for shared operations
- records per-case runtime for both engines
- links against `mk/hbnum_tbig_msvc.hbc` -> `C:/GitHub/tBigNumber/lib/win/msvc64/_tbigNumber_msvc.lib`

Comparative suite currently covers:

- `Add/Sub/Mul/Div(Exact)/Mod/PowInt/GCD/LCM`

Current comparative performance policy:

- `HBNum` keeps full loop profile
- `tBigNumber` runs a smoke loop profile for heavy operations to keep iteration turnaround practical

Rule:

- Benchmark/accuracy iterations must append CSV and LOG outputs to support reproducible comparisons across implementations.
- Harness now separates `HBNum` full accuracy vectors from a `tBigNumber` shared-compatible comparative subset.
- Shared-compatible comparative subset now includes decimal division, decimal multiplication, expanded integer power cases and safe LCM cases; decimal `Mod` and broader `GCD` parity remain outside the shared subset due observed `tBigNumber` behavior.
- Full `tBigNumber` inventory expansion remains pending.

---

### 15.9 Robustness / Property Runner

A dedicated robustness runner now exists in:

- `tests/robustness.prg`

Outputs generated by this runner:

- `mk/msvc64/log/hbnum_robust.log` (detailed randomized/stress trace)

Coverage currently includes:

- randomized integer oracle against Harbour numeric expectations
- randomized decimal oracle with exact scaled-text expectations
- large constructed division/modulo and `GCD/LCM` stress cases
- lifecycle/allocation pressure chains with invariant validation after every step
- structural invariant checks for `nSign/nScale/nUsed/aLimbs`

Execution mode:

- build with `mk/hbnum_robust.hbp`
- run `mk/msvc64/hbnum_robust.exe`

Runtime knobs:

- `HBNUM_ROBUST_SEED`
- `HBNUM_ROBUST_INT_LOOPS`
- `HBNUM_ROBUST_DECIMAL_LOOPS`
- `HBNUM_ROBUST_LARGE_LOOPS`
- `HBNUM_ROBUST_LIFECYCLE_LOOPS`

Validation note:

- the runner accepts `0` loops for a suite, which is useful for isolating/debugging a specific robustness block without editing code.

---
## 16. AI INSTRUCTION BLOCK (FOR PROMPTS)```Follow STRICTLY the HBNum specification.DO NOT:- change structure- introduce new fields- use floating point- mutate inputsENSURE:- base 2^30- normalization- memory safety- invariant compliance```---## 17. PROJECT STRUCTURE

```txt
hbnum/
├─ mk/
│  ├─ go64_lib.bat
│  ├─ go64_test.bat
│  ├─ go64_bench.bat
│  ├─ go64_bench_tbig.bat
│  ├─ go64_robust.bat
│  ├─ hbnum.hbp
│  ├─ hbnum.hbm
│  ├─ hbnum.hbc
│  ├─ hbnum_test.hbp
│  ├─ hbnum_test.hbm
│  ├─ hbnum_test.hbc
│  ├─ hbnum_bench.hbp
│  ├─ hbnum_bench.hbm
│  ├─ hbnum_bench.hbc
│  ├─ hbnum_bench_tbig.hbp
│  ├─ hbnum_bench_tbig.hbm
│  ├─ hbnum_bench_tbig.hbc
│  ├─ hbnum_robust.hbp
│  ├─ hbnum_robust.hbm
│  ├─ hbnum_robust.hbc
│  └─ msvc64/
│     ├─ hbnum.lib
│     ├─ hbnum_test.exe
│     ├─ hbnum_bench.exe
│     ├─ hbnum_bench_tbig.exe
│     ├─ hbnum_robust.exe
│     └─ log/
├─ src/
│  ├─ hb/
│  │  ├─ hbnum.prg
│  │  ├─ hbnum_context.prg
│  │  ├─ hbnum_compare_ops.prg
│  │  ├─ hbnum_math_ops.prg
│  │  └─ hbnum_integer_ops.prg
│  └─ c/
│     ├─ hbnum_core.c
│     ├─ hbnum_core_math.c
│     ├─ hbnum_core_number_theory.c
│     └─ hbnum_native_internal.h
├─ include/
│  └─ hbnum.h
├─ tests/
│  ├─ test.prg
│  ├─ bench_compare.prg
│  ├─ hbnum_test_paths.prg
│  ├─ robustness.prg
│  └─ test.hbp (legacy/direct)
└─ README.md
```
---## 18. STATUS

Under active development.

Current focus:

- correctness
- robustness / stability
- performance foundation

Current implementation snapshot (updated: 2026-04-18):

- [x] Harbour orchestration layer implemented in `src/hb/hbnum.prg`
- [x] C core arithmetic implemented in `src/c/hbnum_core.c`
- [x] Runtime method/export naming collision fixed (`HBNUM_CORE_*`)
- [x] Normalize / Compare / Add / Sub / Mul / Div implemented
- [x] Abs / Neg / IsZero / Clone / FromString / ToString implemented
- [x] Mandatory ADD test set implemented in `tests/test.prg`
- [x] Mandatory SUB test set implemented in `tests/test.prg`
- [x] Mandatory MUL test set implemented in `tests/test.prg`
- [x] Mandatory DIV test set implemented in `tests/test.prg`
- [x] Internal ADD structure test aligned to limb carry at base `2^30`
- [x] Test output now includes operation, expected and actual values
- [x] Test output now persists full execution trace to `mk/msvc64/log/hbnum_tests.log`
- [x] Build structure moved to `mk/` and validated (`mk/go64_lib.bat`)
- [x] Test build structure created in `mk/` and validated (`mk/go64_test.bat`)
- [x] Harbour compare facade added (`Eq/Ne/Gt/Gte/Lt/Lte/Min/Max`)
- [x] Harbour modular classes added (`HBNumCompareOps`, `HBNumMathOps`, `HBNumIntegerOps`)
- [x] C modular file added for advanced math (`src/c/hbnum_core_math.c`)
- [x] Mod operation implemented and tested
- [x] PowInt (integer exponent) implemented and tested
- [x] Precision context implemented with `NIL`-as-unset policy and propagated across returned objects
- [x] `Div()` now resolves exact terminating decimals when precision is omitted and context precision is unset
- [x] `Div()` now raises for non-terminating decimals when no explicit/context precision is available
- [x] `Round/Truncate/Floor/Ceiling` implemented and tested
- [x] Harbour number-theory class added (`HBNumIntegerOps`)
- [x] C modular number-theory file added (`src/c/hbnum_core_number_theory.c`)
- [x] GCD implemented and tested
- [x] LCM implemented and tested
- [x] Benchmark/accuracy runner added (`tests/bench_compare.prg`)
- [x] Benchmark logs/CSV enabled in `mk/msvc64/log/` (`hbnum_bench_compare.log` + `hbnum_bench_compare.csv`)
- [x] Benchmark build flow added in `mk/` (`go64_bench*.bat`, `hbnum_bench*.hbp`)
- [x] Comparative run validated (`hbnum_bench_tbig.exe`) with shared vector set
- [x] Robustness/property runner added (`tests/robustness.prg`)
- [x] Robustness build flow added in `mk/` (`go64_robust.bat`, `hbnum_robust*.hbp`)
- [x] Compare edge-case unit coverage expanded (sign/scale/zero matrix)
- [x] Mod edge-case unit coverage expanded (scale + divisor sign permutations)
- [x] PowInt edge-case unit coverage expanded (decimal base + even negative base + zero base)
- [x] GCD/LCM unit coverage expanded (very large operands + co-prime stress)
- [x] Benchmark accuracy vector set expanded in `tests/bench_compare.prg`
- [x] HBNum-only benchmark rerun validated with expanded vector set (`hbnum_bench.exe`)
- [x] `HBNum x tBigNumber` comparative run validated with expanded shared-compatible subset (`hbnum_bench_tbig.exe`)
- [x] Comparative harness split between HBNum-only stress vectors and shared-compatible `tBigNumber` vectors
- [x] Property/randomized robustness suite validated (`hbnum_robust.exe`)
- [x] Stress lifecycle + large-constructed robustness suites validated (`hbnum_robust.exe`)
- [x] Application Verifier smoke run executed against `hbnum_robust.exe` with `Heaps/Handles/Memory/Leak`
- [ ] Negative exponent policy/coverage still pending for future `Pow`
- [ ] Full comparative matrix pending against broader `tBigNumber` vectors (HBNum-only shared subset expanded)
- [ ] Cross-tool memory analysis beyond Application Verifier still pending if extra tooling becomes available
- [ ] Runtime warning cleanup (`LNK4098`) pending
---## 19. FINAL VISION

HBNum should behave as a native Harbour numeric type.

Fast. Deterministic. Predictable.

No magic. Only correctness and performance.

---

## 20. BUILD PROCESS (MSVC64 - DETAILED)

This project is currently built using Harbour `hbmk2` with MSVC64 toolchain.

### 20.1 Prerequisites

1. Harbour MSVC64 distribution available.
2. Visual Studio 2022 Community with C/C++ build tools installed.
3. `vcvarsall.bat` available at:

```txt
%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat
```

4. Harbour `hbmk2` path configured in:

- [mk/go64_lib.bat](mk/go64_lib.bat)
- [mk/go64_test.bat](mk/go64_test.bat)
- [mk/go64_robust.bat](mk/go64_robust.bat)

```bat
SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
```

### 20.2 Build Files and Roles

- [mk/hbnum.hbp](mk/hbnum.hbp): main library build file (target, sources, libs, includes)
- [mk/hbnum.hbm](mk/hbnum.hbm): shared build flags and package includes
- [mk/hbnum.hbc](mk/hbnum.hbc): package-level defaults (`prgflags`, `hbcs`)
- [mk/hbnum_test.hbp](mk/hbnum_test.hbp): test build file (includes `../tests/test.prg`)
- [mk/hbnum_test.hbm](mk/hbnum_test.hbm): shared build flags for tests
- [mk/hbnum_test.hbc](mk/hbnum_test.hbc): package defaults for tests
- [mk/hbnum_bench.hbp](mk/hbnum_bench.hbp): benchmark/accuracy file (HBNum-only mode)
- [mk/hbnum_bench.hbm](mk/hbnum_bench.hbm): shared build flags for benchmark mode
- [mk/hbnum_bench.hbc](mk/hbnum_bench.hbc): package defaults for benchmark mode
- [mk/hbnum_bench_tbig.hbp](mk/hbnum_bench_tbig.hbp): comparative benchmark file (HBNum x tBigNumber)
- [mk/hbnum_bench_tbig.hbm](mk/hbnum_bench_tbig.hbm): shared build flags for comparative mode
- [mk/hbnum_bench_tbig.hbc](mk/hbnum_bench_tbig.hbc): package defaults for comparative mode
- [mk/hbnum_tbig_msvc.hbc](mk/hbnum_tbig_msvc.hbc): local package pinning the comparative build to `_tbigNumber_msvc.lib`
- [mk/hbnum_robust.hbp](mk/hbnum_robust.hbp): robustness/property runner build file
- [mk/hbnum_robust.hbm](mk/hbnum_robust.hbm): shared build flags for robustness mode
- [mk/hbnum_robust.hbc](mk/hbnum_robust.hbc): package defaults for robustness mode
- [mk/go64_lib.bat](mk/go64_lib.bat): MSVC64 build bootstrap for main target
- [mk/go64_test.bat](mk/go64_test.bat): MSVC64 build bootstrap for test target
- [mk/go64_bench.bat](mk/go64_bench.bat): MSVC64 build bootstrap for HBNum benchmark
- [mk/go64_bench_tbig.bat](mk/go64_bench_tbig.bat): MSVC64 build bootstrap for comparative benchmark
- [mk/go64_robust.bat](mk/go64_robust.bat): MSVC64 build bootstrap for robustness/property runner

Current source composition in `*.hbp`:

- Main/test include `src/hb/hbnum.prg`, `src/hb/hbnum_context.prg`, `src/hb/hbnum_compare_ops.prg`, `src/hb/hbnum_math_ops.prg`, `src/hb/hbnum_integer_ops.prg`
- C sources include `src/c/hbnum_core.c` + `src/c/hbnum_core_math.c` + `src/c/hbnum_core_number_theory.c`
- Benchmark runner source: `tests/bench_compare.prg`
- Test/log path helper source: `tests/hbnum_test_paths.prg`
- Robustness runner source: `tests/robustness.prg`
- Comparative build links local package `mk/hbnum_tbig_msvc.hbc`, which points to `C:/GitHub/tBigNumber/lib/win/msvc64/_tbigNumber_msvc.lib`
- Comparative build links the real Harbour MT VM via `-mt` because `tBigNumber` requests `HB_MT`
- `tbigntst_msvc.hbp` is the standalone test app build; the linked library comes from the MSVC tBigNumber library build, while `mk/hbmk.hbm` only affects the external `tBigNumber` build when that library is rebuilt

### 20.3 Build Command

From project root (recommended):

```bat
cd mk
go64_lib.bat
go64_test.bat
go64_bench.bat
go64_robust.bat
```

Equivalent manual flow:

```bat
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum.hbp -comp=msvc64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum_test.hbp -comp=msvc64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum_bench.hbp -comp=msvc64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum_robust.hbp -comp=msvc64
```

### 20.4 Expected Output

- Main target:

```txt
mk/msvc64/hbnum.lib
```

- Test target:

```txt
mk/msvc64/hbnum_test.exe
```

- Benchmark target (HBNum-only):

```txt
mk/msvc64/hbnum_bench.exe
```

- Comparative benchmark target (HBNum x tBigNumber):

```txt
mk/msvc64/hbnum_bench_tbig.exe
```

- Robustness target:

```txt
mk/msvc64/hbnum_robust.exe
```

- Detailed test log:

```txt
mk/msvc64/log/hbnum_tests.log
```

- Benchmark outputs:

```txt
mk/msvc64/log/hbnum_bench_compare.log
mk/msvc64/log/hbnum_bench_compare.csv
```

- Robustness output:

```txt
mk/msvc64/log/hbnum_robust.log
```

- Logs are always written beside the executable under `log/`, using `hb_ProgName()` to derive the executable directory:

```txt
mk/msvc64/log/
```

- If an old executable exists, batch scripts delete it first.

### 20.5 Known Build Notes

- Current build can emit warning `LNK4098` about runtime library conflict.
- Even with warning, the main build currently produces `mk/msvc64/hbnum.lib`.
- The message "Não foi possível encontrar ...exe" after `del` can appear on first run and is expected when the old binary does not exist yet.
- Application Verifier validation of `hbnum_robust.exe` requires administrator privileges to enable/disable checks.
- Runtime library alignment should be revisited in upcoming iteration.

---

## 21. BUILD CHECKLIST (LIVE)

- [x] Main build files in `mk/` (`hbnum.hbp/.hbm/.hbc`)
- [x] Test build files in `mk/` (`hbnum_test.hbp/.hbm/.hbc`)
- [x] Main build script `mk/go64_lib.bat`
- [x] Test build script `mk/go64_test.bat`
- [x] First main make executed successfully
- [x] First test make executed successfully
- [x] Main build validated after module split (`hbnum_core_math.c`)
- [x] Test build validated after module split (`HBNumCompareOps`/`HBNumMathOps`)
- [x] Main/test build validated after number-theory split (`hbnum_core_number_theory.c` + `HBNumIntegerOps`)
- [x] Benchmark build files in `mk/` (`hbnum_bench.hbp/.hbm/.hbc`)
- [x] Comparative benchmark build files in `mk/` (`hbnum_bench_tbig.hbp/.hbm/.hbc`)
- [x] Robustness build files in `mk/` (`hbnum_robust.hbp/.hbm/.hbc`)
- [x] Benchmark build script `mk/go64_bench.bat`
- [x] Comparative benchmark build script `mk/go64_bench_tbig.bat`
- [x] Robustness build script `mk/go64_robust.bat`
- [x] Benchmark run validated (`hbnum_bench.exe`)
- [x] Comparative benchmark run validated (`hbnum_bench_tbig.exe`)
- [x] Robustness run validated (`hbnum_robust.exe`)
- [ ] Integrate automated test execution step after build

---

## 22. ITERATION POLICY FOR README

This README is a living implementation contract.

For every new implementation iteration, update:

1. Section **11** (implementation checklist state).
2. Section **18** (snapshot + pending items).
3. Section **20** (build process changes, if any).
4. Test coverage items in Section **15** and Section **18**.
5. Section **25** (coding-standard checklist and validation status).

Rule:

- Code change without README status update is incomplete work.

---

## 23. PORTING ROADMAP (FROM SCRATCH, NO COPY)

Goal:

- Reimplement (not copy) most practical capabilities previously available in `tBigNumber`, aligned to HBNum invariants and architecture.

Execution phases:

1. Foundation hardening (current phase started)
- [x] Split initial responsibilities in Harbour classes (`HBNumCompareOps`, `HBNumMathOps`, `HBNumIntegerOps`)
- [x] Split advanced C operations into dedicated files (`hbnum_core_math.c`, `hbnum_core_number_theory.c`)
- [x] Deliver first extension set: compare helpers + `Mod` + `PowInt`

2. Integer-number toolkit
- [x] `GCD` / `LCM`
- [ ] Integer `Factorial`
- [ ] Integer `Fibonacci`
- [ ] Deterministic prime helpers (start with Miller-Rabin)

3. Decimal behavior toolkit
- [x] `Truncate`
- [x] `Round` (current policy: half-up)
- [x] `Floor` / `Ceiling`
- [ ] Scale-oriented formatting helpers

4. Advanced numeric toolkit
- [ ] `Pow` with negative exponent policy + precision
- [x] `SQRT` (integer + decimal precision modes)
- [x] `nthRoot`
- [x] `Log` family (context-driven precision strategy)

5. Quality and reliability
- [x] Comparative benchmark harness baseline (`bench_compare.prg`)
- [x] Expand first shared benchmark vector subset (decimal/sign/large integer cases)
- [x] Validate expanded shared-compatible comparative subset in `hbnum_bench_tbig.exe`
- [ ] Expand comparative vectors based on `tBigNumber` full test inventory
- [x] Property/randomized tests
- [x] Stress tests (large limbs and scale)
- [x] Memory validation with Application Verifier (`Heaps/Handles/Memory/Leak`)
- [ ] Cross-tool memory validation beyond Application Verifier
- [ ] Runtime/link warning cleanup (`LNK4098`)

### 23.1 Port Coverage Map (From Scratch)

Reference source for feature inventory: `tBigNumber` method set.
Implementation rule: reimplement behavior in HBNum architecture (no code copy).

- [x] Arithmetic core: `Add/Sub/Mul/Div/Mod`
- [x] Comparison helpers: `Eq/Ne/Gt/Gte/Lt/Lte/Min/Max`
- [x] Integer power base: `PowInt`
- [x] Number theory base: `GCD/LCM`
- [x] Precision context base: `HBNumContext` + unlimited-core precision policy for approximate decimal operations
- [x] Comparative benchmark baseline: `HBNum x tBigNumber` (shared vector subset)
- [ ] Number theory extended: `Factorial/Fibonacci/MillerRabin`
- [x] Scale/rounding toolkit core: `Round/Truncate/Floor/Ceiling`
- [ ] Scale/rounding toolkit extended: `NoRnd` + formatting helpers
- [x] Root/log toolkit: `SQRT/nthRoot/Log/Ln/Log10`
- [ ] Conversion toolkit: `D2H/H2D/H2B/B2H/D2B/B2D`

---

## 24. TEST EXECUTION PLAN (CURRENT ITERATION)

Build:

```bat
cd mk
go64_lib.bat
go64_test.bat
go64_robust.bat
```

Run tests:

```bat
cd mk
msvc64\hbnum_test.exe
```

Run benchmark/accuracy (HBNum-only):

```bat
cd mk
go64_bench.bat
msvc64\hbnum_bench.exe
```

Run comparative benchmark/accuracy (HBNum x tBigNumber):

```bat
cd mk
go64_bench_tbig.bat
msvc64\hbnum_bench_tbig.exe
```

Target only the root/log comparative subset and skip performance loops:

```bat
cd mk
set HBNUM_BENCH_FILTER=ROOTLOG
set HBNUM_BENCH_SKIP_PERF=1
msvc64\hbnum_bench_tbig.exe
```

Run robustness/property/stress suite:

```bat
cd mk
go64_robust.bat
msvc64\hbnum_robust.exe
```

Optional robustness tuning:

```bat
set HBNUM_ROBUST_SEED=20260418
set HBNUM_ROBUST_INT_LOOPS=1000
set HBNUM_ROBUST_DECIMAL_LOOPS=1000
set HBNUM_ROBUST_LARGE_LOOPS=250
set HBNUM_ROBUST_LIFECYCLE_LOOPS=5000
msvc64\hbnum_robust.exe
```

Optional memory-safety smoke with Application Verifier (administrator privileges required):

```bat
cd mk
appverif.exe -enable Heaps Handles Memory Leak -for hbnum_robust.exe
msvc64\hbnum_robust.exe
appverif.exe -export log -for hbnum_robust.exe -with To=F:\GitHub\hbnum\mk\hbnum_robust_appverif.xml
appverif.exe -disable * -for hbnum_robust.exe
```

Prerequisite for comparative mode:

- `C:/GitHub/tBigNumber` available with `include/` and `lib/win/msvc64/_tbigNumber_msvc.lib`

Validate detailed log:

```bat
cd mk
type msvc64\log\hbnum_tests.log
```

Validate benchmark artifacts:

```bat
cd mk
type msvc64\log\hbnum_bench_compare.log
type msvc64\log\hbnum_bench_compare.csv
```

Validate robustness artifact:

```bat
cd mk
type msvc64\log\hbnum_robust.log
```

Minimum acceptance for this iteration:

- [x] Existing Add/Sub/Mul/Div tests still passing
- [x] Expanded compare edge-case tests passing
- [x] Expanded `Mod` edge-case tests passing
- [x] Expanded `PowInt` edge-case tests passing
- [x] Expanded `GCD`/`LCM` large/co-prime tests passing
- [x] No regression in no-mutation behavior checks
- [x] Benchmark harness generated log + CSV outputs
- [x] HBNum-only benchmark/accuracy rerun validated with expanded vector set (`hbnum_bench.exe`)
- [x] Harbour commit check wrapper passing after touched-file updates (`mk/go64_commit_check.bat`)
- [x] Comparative run validated with expanded shared-compatible vector set in `hbnum_bench_tbig.exe`
- [x] Comparative harness now preserves a stricter `tBigNumber` subset while keeping broader HBNum-only stress vectors
- [x] Property/randomized robustness suite passing in `hbnum_robust.exe`
- [x] Large/lifecycle stress suites passing in `hbnum_robust.exe`
- [x] Robustness runner generated detailed log output (`mk/msvc64/log/hbnum_robust.log`)
- [x] Application Verifier smoke run completed for `hbnum_robust.exe` with no verifier events recorded during the validated run

---

## 25. CODING STANDARD (MANDATORY)

This section defines repository-wide formatting and file-header standards.

### 25.1 Public Domain Header

All project-owned code/build files MUST contain the marker:

```txt
hbnum: Released to Public Domain.
```

Current mandatory scope:

- `src/`
- `include/`
- `tests/`
- `mk/`

Note:

- Third-party or imported tooling should keep original license headers.

### 25.2 Line Endings and Whitespace

Mandatory text-file conventions:

- Canonical line ending: `CRLF` (`\r\n`)
- No mixed line endings (`LF` and `CRLF`) inside or across project text files
- No trailing whitespace at end of lines
- Final newline required at end of file

### 25.3 Repository Enforcement

Repository now includes:

- `.editorconfig` for editor-side normalization (`CRLF`, final newline, trailing whitespace trim)
- `.gitattributes` for Git-side normalization (`eol=crlf` for text files)
- `.gitignore` for local-sensitive metadata and generated logs/verification artifacts

### 25.4 Quick Validation Commands

Trailing whitespace scan:

```powershell
rg -n --pcre2 "[ \t]+$" src include tests mk README.md ChangeLog.txt
```

Header marker scan (files that still need the marker):

```powershell
$files = rg --files src include tests mk | ? { [IO.Path]::GetExtension($_).ToLower() -in '.prg','.c','.h','.ch','.hbp','.hbc','.hbm','.bat' }
$files | ? { -not ([IO.File]::ReadAllText((Join-Path (Get-Location) $_)) -match 'hbnum:\s*Released to Public Domain\.') }
```

### 25.5 Coding Standard Checklist (LIVE)

- [x] `.editorconfig` created and tracked
- [x] `.gitattributes` created and tracked
- [x] `.gitignore` updated for sensitive local files (e.g. `.openclaude-profile.json`)
- [x] Test/benchmark/robustness log files ignored by pattern
- [x] Public-domain marker applied to project-owned files in `src/include/tests/mk`
- [x] Trailing whitespace removed from project-owned text files
- [x] Text files normalized to `CRLF`
- [x] Touched files revalidated with no trailing whitespace (`tests/robustness.prg`, `mk/hbnum_robust.hbp`, `mk/hbnum_robust.hbm`, `mk/hbnum_robust.hbc`, `mk/go64_robust.bat`, `.gitignore`, `README.md`)
- [x] Harbour commit check rerun successfully after this iteration (`mk/go64_commit_check.bat`)
- [ ] Add CI/pre-commit gate to reject non-standard EOL/whitespace/header regressions

---

## 26. HARBOUR PRE-COMMIT STANDARD (`check.hb` / `commit.hb`)

`bin/check.hb` and `bin/commit.hb` are the Harbour-style quality gates for filename/content validation before commit.

### 26.1 Canonical Flow in HBNum

Use `commit.hb` as canonical gate.

Recommended wrapper (Windows):

```bat
cd mk
go64_commit_check.bat
```

Direct full-repository audit:

```bat
F:\harbour_msvc\bin\win\msvc64\hbrun.exe bin\commit.hb -c
```

Notes:

- `go64_commit_check.bat` uses `--check-only` (recommended for commit gate).
- `-c` is a full scan/audit command.

### 26.2 Main Rules Enforced

- filename must be ASCII-7
- filename extension must be known in `.gitattributes`
- no TABs (except allowlist)
- no BOM
- no mixed EOL
- `.bat` must use `CRLF`; `.sh` must use `LF`
- no trailing whitespace
- exactly one newline at EOF
- text must be UTF-8 or ASCII-7
- source files must include license marker (`public domain`, `copyright`, or `license`)
- C sources must not use `//` comments

### 26.3 HBNum Alignment Applied

- `check.hb` root was aligned to this repository root.
- `.gitignore` was adjusted so local editor artifacts (`.vscode/`) are ignored by Harbour scanners.
- `.gitattributes` now includes project text extensions used locally (`*.ucf`, `*.lst`).
- `CRLF` normalization and whitespace cleanup were reapplied.

### 26.4 Compliance Checklist (LIVE)

- [x] `hbrun.exe bin/commit.hb -c` passing with zero findings
- [x] Wrapper script created: `mk/go64_commit_check.bat`
- [x] `.openclaude-profile.json` ignored
- [x] Test/benchmark log outputs ignored
- [x] `.vscode` local artifacts ignored for scanner flow
- [ ] Add automated repository bootstrap step to install git pre-commit hook from `commit.hb`

---
