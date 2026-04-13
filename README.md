# HBNumHBNum is an arbitrary precision numeric library designed for the Harbour ecosystem.> ⚠️ This document is the SINGLE SOURCE OF TRUTH.> Any implementation MUST strictly follow these rules.---## 1. SYSTEM OVERVIEWHBNum is:> A **C-based numeric engine with a Harbour interface**Execution model:Harbour → orchestrationC       → computation### HARD RULEIF heavy math is implemented in Harbour → WRONG---## 2. DESIGN PRINCIPLES- Harbour-first API (interface only)- ALL heavy computation MUST be in C- Arbitrary precision (memory-bound)- Immutable-style operations- Deterministic arithmetic (no floating point)- Extensible architecture---## 3. DATA STRUCTURE (MANDATORY)Every number MUST follow EXACTLY this structure:```harbour
{
   "nSign"  => -1 | 0 | 1,
   "nScale" => >= 0,
   "nUsed"  => >= 0,
   "aLimbs" => array of integers
}
```
---## 3.1 Field Rules| Field  | Rule                                  || ------ | ------------------------------------- || nSign  | -1 (negative), 0 (zero), 1 (positive) || nScale | decimal precision                     || nUsed  | number of used limbs                  || aLimbs | little-endian                         |---## 3.2 Limb RulesBase MUST be:```c#define HBNUM_BASE ((HB_U32)1073741824UL) // 2^30```Each limb MUST satisfy:```bash0 <= limb < HBNUM_BASE```---## 4. NUMERIC MODELRepresentation:```bashvalue = integer * 10^(-nScale)```Example:```bash"123.45" →aLimbs = [12345]nScale = 2```---## 5. CORE INVARIANTS (CRITICAL)These MUST ALWAYS hold:- nUsed == len(aLimbs)- No leading zero limbs (except zero)- Zero representation:```harbournSign = 0nUsed = 0aLimbs = {}```- No shared memory between objects- All operations return NEW structures---## 6. OPERATION CONTRACT (MANDATORY)Every operation MUST:1. Receive TWO hashes2. NEVER mutate inputs3. Return NEW hash4. Normalize result5. Enforce invariants---## 7. NORMALIZATION RULESNormalization MUST:- Remove leading zero limbs- Adjust nUsed- Fix sign for zero- Ensure invariant compliance---## 8. ARCHITECTURE

```bash
Harbour Layer (API)
        ↓
C Core (Engine)
```

Current modular layout (started in this iteration):

```bash
Harbour
  - HBNum (core object lifecycle + delegation)
  - HBNumCompareOps (relational/comparison helpers)
  - HBNumMathOps (modular integer-math helpers)
  - HBNumIntegerOps (number-theory integer helpers)

C
  - hbnum_core.c      (core arithmetic + parse/hash bridge)
  - hbnum_core_math.c (mod + integer power extension)
  - hbnum_core_number_theory.c (gcd + lcm extension)
```
---### 8.1 Harbour Responsibilities- Input normalization- Object lifecycle- Delegation to C- Result wrapping---### 8.2 C Responsibilities- Arithmetic operations- Carry / borrow logic- Limb manipulation- Normalization- Performance-critical logic---## 9. C IMPLEMENTATION RULES (STRICT)### MUST- Use HB_FUNC- Use PHB_ITEM- Use hb_array*, hb_hash*- Use hb_item*- Use hb_ret*- Use hb_xgrab / hb_xfree- Prefer stack allocation when possible---### MUST NOT- malloc inside loops- realloc inside loops- floating point usage- pointer sharing between objects- Harbour-based arithmetic loops---## 10. HARBOUR API (REFERENCE)```harbourCLASS HBNum   DATA hbNum   METHOD New(xValue)   METHOD FromString(cValue)   METHOD FromInt(nValue)   METHOD Clone()   METHOD Add(xValue)
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

   METHOD Abs()
   METHOD Neg()
   METHOD IsZero()
   METHOD Normalize()   METHOD ToString()ENDCLASS```---## 11. IMPLEMENTATION CHECKLIST (FOR AI)

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
- [x] Benchmark/accuracy harness created (`tests/bench_compare.prg`)
- [x] CSV + LOG outputs created for benchmark runs
- [x] Dedicated benchmark build flow created (`mk/hbnum_bench*.hbp`)
- [ ] No overflow risk fully validated with stress/fuzz tests
- [ ] Memory safety fully validated with dedicated tooling

Notes:

- C core uses `HB_U64` for carry/borrow intermediates.
- All operations exposed to Harbour return NEW hashes.
- C exports use `HBNUM_CORE_*` namespace to avoid method-name collisions in Harbour.
- Remaining unchecked items are validation tasks, not design gaps.
---## 12. PERFORMANCE RULES- Prefer stack over heap- Minimize allocations- Avoid copying arrays- Avoid dynamic resizing in loops- Optimize memory locality---## 13. FORBIDDEN PRACTICES- Floating point operations- Harbour loops for arithmetic- String-based math- Shared limb arrays- Premature optimization---## 14. DEVELOPMENT ORDERImplement in this sequence:1. Normalize2. Compare3. Add / Sub4. Mul5. Div---## 15. TEST CONTRACT (MANDATORY)> Every implementation MUST include test cases.---### 15.1 Test RequirementsEach operation MUST include:- Simple case- Carry / borrow case- Different sizes- Negative values- Zero handling- Extreme values---### 15.2 Test Format```harbourFUNCTION Test_Add_Simple()   LOCAL oA := HBNum():FromString("2")   LOCAL oB := HBNum():FromString("3")   LOCAL oR := oA:Add(oB)   RETURN oR:ToString() == "5"```---### 15.3 Mandatory ADD Tests
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
// simple
"10" / "2" (precision 0) = "5"

// truncation
"7" / "2" (precision 0) = "3"

// precision
"1" / "8" (precision 3) = "0.125"

// negative
"-10" / "4" (precision 0) = "-2"
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
- default location: current execution directory (for `mk/go64_test.bat`, this is `mk/`)

This format is mandatory for faster diagnostics during iterative development.

---

### 15.8 Comparative Accuracy/Performance (HBNum x tBigNumber)

A dedicated runner now exists in:

- `tests/bench_compare.prg`

Outputs generated by this runner:

- `hbnum_bench_compare.log` (detailed execution trace)
- `hbnum_bench_compare.csv` (structured results for analysis)

Execution modes:

1. HBNum-only benchmark mode:
- build with `mk/hbnum_bench.hbp`
- validates HBNum accuracy vectors and performance baselines

2. Comparative mode (HBNum vs tBigNumber):
- build with `mk/hbnum_bench_tbig.hbp`
- compares canonicalized outputs for shared operations
- records per-case runtime for both engines
- links against `C:/GitHub/tBigNumber/hbc/_tbignumber.hbc`

Comparative suite currently covers:

- `Add/Sub/Mul/Div(Exact)/Mod/PowInt/GCD/LCM`

Current comparative performance policy:

- `HBNum` keeps full loop profile
- `tBigNumber` runs a smoke loop profile for heavy operations to keep iteration turnaround practical

Rule:

- Benchmark/accuracy iterations must append CSV and LOG outputs to support reproducible comparisons across implementations.

---
## 16. AI INSTRUCTION BLOCK (FOR PROMPTS)```Follow STRICTLY the HBNum specification.DO NOT:- change structure- introduce new fields- use floating point- mutate inputsENSURE:- base 2^30- normalization- memory safety- invariant compliance```---## 17. PROJECT STRUCTURE

```txt
hbnum/
├─ mk/
│  ├─ go64.bat
│  ├─ go64_test.bat
│  ├─ go64_bench.bat
│  ├─ go64_bench_tbig.bat
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
│  └─ msvc64/
│     ├─ hbnum.exe
│     ├─ hbnum_test.exe
│     ├─ hbnum_bench.exe
│     └─ hbnum_bench_tbig.exe
├─ src/
│  ├─ hb/
│  │  ├─ hbnum.prg
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
│  ├─ tbig_link_stubs.prg
│  └─ test.hbp (legacy/direct)
└─ README.md
```
---## 18. STATUS

Under active development.

Current focus:

- correctness
- stability
- performance foundation

Current implementation snapshot (updated: 2026-04-12):

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
- [x] Test output now persists full execution trace to `hbnum_tests.log`
- [x] Build structure moved to `mk/` and validated (`mk/go64.bat`)
- [x] Test build structure created in `mk/` and validated (`mk/go64_test.bat`)
- [x] Harbour compare facade added (`Eq/Ne/Gt/Gte/Lt/Lte/Min/Max`)
- [x] Harbour modular classes added (`HBNumCompareOps`, `HBNumMathOps`, `HBNumIntegerOps`)
- [x] C modular file added for advanced math (`src/c/hbnum_core_math.c`)
- [x] Mod operation implemented and tested
- [x] PowInt (integer exponent) implemented and tested
- [x] Harbour number-theory class added (`HBNumIntegerOps`)
- [x] C modular number-theory file added (`src/c/hbnum_core_number_theory.c`)
- [x] GCD implemented and tested
- [x] LCM implemented and tested
- [x] Benchmark/accuracy runner added (`tests/bench_compare.prg`)
- [x] Benchmark logs/CSV enabled (`hbnum_bench_compare.log` + `hbnum_bench_compare.csv`)
- [x] Benchmark build flow added in `mk/` (`go64_bench*.bat`, `hbnum_bench*.hbp`)
- [x] Comparative run validated (`hbnum_bench_tbig.exe`) with shared vector set
- [ ] Full Compare test matrix pending
- [ ] Full Mod edge-case matrix pending (scale + divisor sign permutations)
- [ ] Full Pow matrix pending (negative exponent with precision policy)
- [ ] Full GCD/LCM edge-case matrix pending (very large operands + co-prime stress)
- [ ] Full comparative matrix pending against broader `tBigNumber` vectors (beyond current shared subset)
- [ ] Property-based randomized suite pending
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

- [mk/go64.bat](mk/go64.bat)
- [mk/go64_test.bat](mk/go64_test.bat)

```bat
SET HB_BASE_PATH="F:\harbour_msvc\bin\win\msvc64\hbmk2"
```

### 20.2 Build Files and Roles

- [mk/hbnum.hbp](mk/hbnum.hbp): main build file (target, sources, libs, includes)
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
- [mk/go64.bat](mk/go64.bat): MSVC64 build bootstrap for main target
- [mk/go64_test.bat](mk/go64_test.bat): MSVC64 build bootstrap for test target
- [mk/go64_bench.bat](mk/go64_bench.bat): MSVC64 build bootstrap for HBNum benchmark
- [mk/go64_bench_tbig.bat](mk/go64_bench_tbig.bat): MSVC64 build bootstrap for comparative benchmark

Current source composition in `*.hbp`:

- Main/test include `src/hb/hbnum.prg`, `src/hb/hbnum_compare_ops.prg`, `src/hb/hbnum_math_ops.prg`, `src/hb/hbnum_integer_ops.prg`
- C sources include `src/c/hbnum_core.c` + `src/c/hbnum_core_math.c` + `src/c/hbnum_core_number_theory.c`
- Benchmark runner source: `tests/bench_compare.prg`
- Comparative build links external package: `C:/GitHub/tBigNumber/hbc/_tbignumber.hbc`
- Comparative build includes local link shim: `tests/tbig_link_stubs.prg` (resolves `HB_MT` dependency)

### 20.3 Build Command

From project root (recommended):

```bat
cd mk
go64.bat
go64_test.bat
go64_bench.bat
```

Equivalent manual flow:

```bat
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum.hbp -comp=msvc64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum_test.hbp -comp=msvc64
F:\harbour_msvc\bin\win\msvc64\hbmk2 hbnum_bench.hbp -comp=msvc64
```

### 20.4 Expected Output

- Main target:

```txt
mk/msvc64/hbnum.exe
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

- Detailed test log:

```txt
mk/hbnum_tests.log
```

- Benchmark outputs:

```txt
mk/hbnum_bench_compare.log
mk/hbnum_bench_compare.csv
```

- If `hbnum_test.exe` is executed directly from `mk/msvc64`, log can be created in:

```txt
mk/msvc64/hbnum_tests.log
```

- If an old executable exists, batch scripts delete it first.

### 20.5 Known Build Notes

- Current build can emit warning `LNK4098` about runtime library conflict.
- Even with warning, build currently produces `mk/msvc64/hbnum.exe`.
- The message "Não foi possível encontrar ...exe" after `del` can appear on first run and is expected when the old binary does not exist yet.
- Runtime library alignment should be revisited in upcoming iteration.

---

## 21. BUILD CHECKLIST (LIVE)

- [x] Main build files in `mk/` (`hbnum.hbp/.hbm/.hbc`)
- [x] Test build files in `mk/` (`hbnum_test.hbp/.hbm/.hbc`)
- [x] Main build script `mk/go64.bat`
- [x] Test build script `mk/go64_test.bat`
- [x] First main make executed successfully
- [x] First test make executed successfully
- [x] Main build validated after module split (`hbnum_core_math.c`)
- [x] Test build validated after module split (`HBNumCompareOps`/`HBNumMathOps`)
- [x] Main/test build validated after number-theory split (`hbnum_core_number_theory.c` + `HBNumIntegerOps`)
- [x] Benchmark build files in `mk/` (`hbnum_bench.hbp/.hbm/.hbc`)
- [x] Comparative benchmark build files in `mk/` (`hbnum_bench_tbig.hbp/.hbm/.hbc`)
- [x] Benchmark build script `mk/go64_bench.bat`
- [x] Comparative benchmark build script `mk/go64_bench_tbig.bat`
- [x] Benchmark run validated (`hbnum_bench.exe`)
- [x] Comparative benchmark run validated (`hbnum_bench_tbig.exe`)
- [ ] Integrate automated test execution step after build

---

## 22. ITERATION POLICY FOR README

This README is a living implementation contract.

For every new implementation iteration, update:

1. Section **11** (implementation checklist state).
2. Section **18** (snapshot + pending items).
3. Section **20** (build process changes, if any).
4. Test coverage items in Section **15** and Section **18**.

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
- [ ] `Truncate`
- [ ] `Round` (policy-defined)
- [ ] `Floor` / `Ceiling`
- [ ] Scale-oriented formatting helpers

4. Advanced numeric toolkit
- [ ] `Pow` with negative exponent policy + precision
- [ ] `SQRT` (integer + decimal precision modes)
- [ ] `nthRoot`
- [ ] `Log` family (if precision strategy is approved)

5. Quality and reliability
- [x] Comparative benchmark harness baseline (`bench_compare.prg`)
- [ ] Expand comparative vectors based on `tBigNumber` full test inventory
- [ ] Property/randomized tests
- [ ] Stress tests (large limbs and scale)
- [ ] Memory validation with tooling
- [ ] Runtime/link warning cleanup (`LNK4098`)

### 23.1 Port Coverage Map (From Scratch)

Reference source for feature inventory: `tBigNumber` method set.
Implementation rule: reimplement behavior in HBNum architecture (no code copy).

- [x] Arithmetic core: `Add/Sub/Mul/Div/Mod`
- [x] Comparison helpers: `Eq/Ne/Gt/Gte/Lt/Lte/Min/Max`
- [x] Integer power base: `PowInt`
- [x] Number theory base: `GCD/LCM`
- [x] Comparative benchmark baseline: `HBNum x tBigNumber` (shared vector subset)
- [ ] Number theory extended: `Factorial/Fibonacci/MillerRabin`
- [ ] Scale/rounding toolkit: `Round/NoRnd/Truncate/Floor/Ceiling`
- [ ] Root/log toolkit: `SQRT/nthRoot/Log/Ln/Log10`
- [ ] Conversion toolkit: `D2H/H2D/H2B/B2H/D2B/B2D`

---

## 24. TEST EXECUTION PLAN (CURRENT ITERATION)

Build:

```bat
cd mk
go64.bat
go64_test.bat
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

Prerequisite for comparative mode:

- `C:/GitHub/tBigNumber` available with `hbc/_tbignumber.hbc` and `lib/win/msvc64/_tbigNumber.lib`

Validate detailed log:

```bat
cd mk
type hbnum_tests.log
```

Validate benchmark artifacts:

```bat
cd mk
type hbnum_bench_compare.log
type hbnum_bench_compare.csv
```

Minimum acceptance for this iteration:

- [x] Existing Add/Sub/Mul/Div tests still passing
- [x] New compare helper tests passing
- [x] New `Mod` tests passing
- [x] New `PowInt` tests passing
- [x] New `GCD`/`LCM` tests passing
- [x] No regression in no-mutation behavior checks
- [x] Benchmark harness generated log + CSV outputs
- [x] Comparative run validated for shared vector subset (`hbnum_bench_tbig.exe`)
- [ ] Comparative run validated with full `tBigNumber` vector expansion

---
