# Formal verification harnesses

The Certora RateHarness exposes the actual InterestRateModel library. Rate.spec specifies bounds and monotonicity over utilization 0 through 1e18.
Local compilation and CVL checking succeeded with Certora CLI 8.19.1, Java 21 and solc 0.8.38 without IR. This establishes specification validity only. The optimized IR build path and cloud proof remain open.
The successful Halmos harness, exact solver invocation and raw result are preserved in evidence/closure-2026-11-08/. The uint64 monotonic inputs cover every valid utilization <= 1e18.
