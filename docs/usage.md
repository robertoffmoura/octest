# Usage

## Test root resolution

The runner discovers every `Test_*.m` file under the **test root** and runs
the classes it finds:

1. If the `TEST_ROOT` environment variable is set, the root is that path.
2. Otherwise the current working directory is used.

So from your repository root, `runoctests()` runs exactly your tests; from
the octest repository root, it runs the framework's selftests.

Directories named `.git` and `private` are skipped. A subdirectory that
contains `OctaveTestCase.m` is treated as a vendored copy of the framework
and skipped as well, so a framework installed inside your repository never
leaks its own tests into your suite.

## Targets

```
runoctests()                                       % everything under the root
runoctests('Test_myclass')                         % one class
runoctests('Test_myclass/testFoo')                 % one method
runoctests('Test_myclass/testFoo(2,"x",)')         % a positional parameter subset
runoctests('testFoo')                              % a method, resolved by name
runoctests('/path/to/Test_other.m')                % a single test file
```

See [parameterized-tests.md](parameterized-tests.md) for the filter syntax.

## Setup

### Install as a git submodule

On your project's root, track the test framework as a git submodule
(`git submodule add https://github.com/robertoffmoura/octest`). This pins the
framework version, makes the dependency visible in .gitmodules, and
keeps clones of your project reproducible.

Note that a plain git clone of your project does not
populate submodules: contributors must either clone your project with
`git clone --recurse-submodules`; or `git clone` normally and then run `git submodule update --init`
afterwards (the octest/ folder stays empty until then). The runner skips any folder containing
OctaveTestCase.m during discovery, so a nested checkout never leaks
its own tests into your suite.

To fetch updates for the testing framework, run `git submodule update --remote` from your project's directory.

### Add to path

Add it to the path once, e.g. from your `startup.m` or from your test setup script:

```matlab
addpath('/path/to/octest');
```

## Continuous integration

The runner exits with status 1 when any test failed or errored and the `CI`
environment variable is set. A minimal GitHub Actions workflow:

```yaml
name: tests
on: [push, pull_request]
jobs:
  octave:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - run: sudo apt-get update && sudo apt-get install -y octave octave-statistics xvfb
      - run: xvfb-run -a octave --no-gui --eval "addpath('/path/to/octest'); pkg load statistics; runoctests();"
        env:
          CI: 'true'
```

Headless Octave needs an X display for figure-creating tests; the
`xvfb-run` wrapper provides one.
