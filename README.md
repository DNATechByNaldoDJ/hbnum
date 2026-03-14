# HBNum

HBNum is an arbitrary precision numeric library designed for the Harbour ecosystem.

The goal of HBNum is to provide high-performance big number arithmetic while following the philosophy and conventions of the Harbour language. Instead of reinventing a runtime or external numeric system, HBNum integrates naturally with Harbour, using its object model and native C runtime facilities.

HBNum is designed to support extremely large numbers limited only by available memory, making it suitable for applications such as:

- high precision calculations
- cryptography
- financial and scientific computing
- large integer arithmetic
- algorithmic experimentation

## Design principles

HBNum follows a few core principles:

- **Harbour first** – the public API follows Harbour conventions.
- **Native performance** – heavy numeric operations are implemented in C using the Harbour runtime.
- **Arbitrary precision** – numbers are not limited by native integer sizes.
- **Clean architecture** – Harbour wrapper + C computational core.

Internally, HBNum represents numbers using base-2³⁰ limbs stored in little-endian order, a strategy used by several mature arbitrary precision implementations.

## Project structure

```

hbnum/
│
├─ src/
│ ├─ hb/
│ │ └─ hbnum.prg
│ │
│ └─ c/
│ └─ hbnum_core.c
│
├─ include/
│ └─ hbnum.h
│
├─ tests/
│ └─ test.prg
│
├─ hbnum.hbp
└─ README.md

```

## Status

HBNum is currently under development.  
The first milestone focuses on implementing a robust arbitrary precision integer core.

## Long term goals

- Arbitrary precision integers
- Arbitrary precision decimals
- Modular arithmetic
- Cryptographic primitives
- Advanced multiplication algorithms (Karatsuba, Toom-Cook)

## Philosophy

HBNum aims to become a natural numeric extension of Harbour — a library that feels like it has always belonged to the language.
```

