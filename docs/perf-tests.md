# Performance tests

Performance tests subclass `OctavePerfTestCase` and wrap the measured code
in a `while tc.keepMeasuring` loop:

```matlab
classdef Test_alg < OctavePerfTestCase
    methods
        function testSorting(tc)
            x = rand(1, 1e6);
            while tc.keepMeasuring
                sort(x);
            end
        end
    end
end
```

## How measurement works

Each loop iteration is one measurement: `keepMeasuring` returns the wall time
elapsed since the previous call, so exactly one body execution is timed per
iteration. The scheme follows MATLAB's `matlab.perftest` defaults:

1. The first `NumWarmups` (default 5) measurements are discarded.
2. Samples are collected until their **relative margin of error** falls
   below `RelativeMarginOfError` (default 0.05, i.e. 5%):

   ```
   relMoE = T * std(samples) / (mean(samples) * sqrt(n))
   ```

   where `T` is the Student-t score for `ConfidenceLevel` (default 0.95)
   with `n - 1` degrees of freedom.
3. At least `MinSamples` (default 4) samples are always collected.
4. Sampling stops at `MaxSamples` (default 256) even if the margin was not
   reached.

Very fast code (mean close to the timer resolution) runs to the cap; use a
larger workload or loop iterations for such cases. All five knobs are public
properties and can be overridden per class.

The Student-t quantile uses `tinv` when available (Octave's statistics
package, MATLAB's Statistics toolbox); otherwise a normal approximation
(1.96) is used.

## Reporting

After each performance case the runner prints the measured statistics
inline, and after the class it prints a sample summary table:

```
  Test_alg/testSorting: 1.596 s mean, 5.0% MoE, n=159 (5 warmups)

Sample summary:
     Name                                   n        Mean         Std         Min         Max      MoE
     --------------------------------------------------------------------------------------------------
     Test_alg/testSorting                  159     1.59606    0.509235     1.17532     3.79525     5.0%
```

Partial samples are still reported when a case throws mid-loop.

Assertions after the loop work as usual, so a performance test can verify
correctness of the last result:

```matlab
            while tc.keepMeasuring
                result = sort(x);
            end
            tc.verifyEqual(result, expected);
```

The collected samples are available through `tc.sampleStats()` (a struct
with `NumSamples`, `Mean`, `Std`, `Min`, `Max`, `RelMoE`, `NumWarmups`).
