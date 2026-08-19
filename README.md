# octest

A lightweight test framework for Octave (and MATLAB), with parameterized tests,
performance measurements, setUp/tearDown methods, and wildcard matchers for assertions.

## Features

- **Runner**: discovers every `Test_*.m` file under your repo root and runs
  it, with per-class verdicts, an inline failure banner per failing case, and
  a failure summary when at least one test fails.
- **Parameterized tests**: declare argument values in a comment directly
  above the test method; the runner executes every cartesian combination as
  an isolated verdict.
- **Targeted runs**: run one class, one method, or a positional subset of a
  parameterization: `runoctests('Test_myclass/testFoo("a",,2)')`.
- **`setUp`/`tearDown`**: run around every case (including each
  parameterized case), with tearDown guaranteed even when setUp or the test
  throws.
- **Performance tests**: MATLAB-style `while tc.keepMeasuring` sampling with
  Student-t statistics; timings are printed inline and in a per-class sample
  summary.
- **Rich assertions**: `verifyEqual` (struct/cell recursion, `AbsTol`,
  `Any` wildcard matchers), `verifyTrue/False`, `verifyNumElements`,
  range checks, all with `file:line` diagnostics.
- **CI friendly**: exits non-zero when any test fails and `CI` is set.
- **Cross-engine**: runs on Octave and MATLAB; MATLAB-specific behaviors are
  documented.

## Quick start

Octave:

```octave
cd /path/to/octest
addpath(pwd)            % or keep it on your path permanently
pkg load statistics     % required by the runner

cd /path/to/your/repo   % where your Test_*.m files live
runoctests()
```

MATLAB:

```matlab
addpath('/path/to/octest')
cd('/path/to/your/repo')
runoctests()
```

The runner uses the current working directory as the test root; set the
`TEST_ROOT` environment variable to point it somewhere else.

## Writing tests

A test class subclasses `OctaveTestCase`; every `test*` method is a test:

```matlab
classdef Test_math < OctaveTestCase
    methods
        function testAddition(tc)
            tc.verifyEqual(2 + 2, 4);
        end
    end
end
```

Run it:

```
>> runoctests('Test_math/testAddition')
Running Test_math/testAddition
.
Done Test_math
__________

Totals:
   1 Passed, 0 Failed, 0 Errored.
```

See the docs for the full feature set:

- [Writing tests](docs/writing-tests.md) — assertions, `Any` matchers,
  `setUp`/`tearDown`.
- [Parameterized tests](docs/parameterized-tests.md) — `% @arg = {...}`
  annotations, cartesian products, positional targeting.
- [Performance tests](docs/perf-tests.md) — `keepMeasuring`, sample
  statistics, the sample summary.
- [Usage](docs/usage.md) — test root resolution, setup, CI.

## Setup

There are two steps to setting up the framework with your own repository:

1. **Install**: Track it as a git submodule (`git submodule add https://github.com/robertoffmoura/octest`)
  on your project's root.
2. **Add to path**: `addpath('path/to/octest')` from your `startup.m` or test setup script.

See [docs/usage.md](docs/usage.md) for details.

## Requirements

- Octave 6+ (statistics package) or MATLAB R2016b+.
- The statistics package is only needed for the Student-t quantile used by
  performance tests; the runner falls back to a normal approximation when it
  is unavailable.

## Development

The framework tests itself: from the repository root,

```octave
cd /path/to/octest
pkg load statistics
runoctests()
```

runs the selftests in `selftests/` (testParams units, runner behavior via
scratch test roots, `keepMeasuring` sampling). The `standalone/` folder
contains self-contained probes of the parameter and perf machinery that need
no repository at all: useful for cross-checking on machines without a
checkout.

## License

MIT. See [LICENSE](LICENSE).
