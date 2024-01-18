# Reduction Case Study

This repository hosts the sample code used in the HIP documentation.

## Structure

The code structure follows mostly that of
[rocPRIM](https://github.com/ROCmSoftwarePlatform/rocPRIM), differing in a few
subtle, mostly self-serving ways:

- Unbound by the C++14 requirement of rocPRIM dictated by hipCUB and rocThrust,
  this repository uses C++20 as the baseline.
- As such, implementation are free to make use of some TMP/constexpr helper
  functions found within [`include/tmp_utils.hpp`](include/tmp_utils.hpp).
- The tests and benchmarks don't initialize resources multiple times, but do so
  just once and reuse the same input for tests/benhcmarks of various sizes.
  - Neither do tests, nor the benchmarks use prefixes for input initialization.
    Instead they both create a function object storing all state which tests
    capture by reference.
- "Diffing" the various implementations in succession reveals the minor changes
  between each version. `v0.hpp` is a simple Parallel STL implementation which
  is used for verification and a baseline of performance for comparison.
- The `examples` folder holds the initial implementations of the various
  optimization levels of the benchmarks before the repo got split into tests
  and benchmarks with some degree of deduplication and common structure.
