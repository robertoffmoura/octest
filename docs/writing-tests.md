# Writing tests

A test class subclasses `OctaveTestCase`. Every method whose name starts with
`test` is a test case; any other method is a helper.

```matlab
classdef Test_math < OctaveTestCase
    methods
        function testAddition(tc)
            tc.verifyEqual(2 + 2, 4);
        end
    end
end
```

## Assertions

All verification methods are named `verify*`. A failed verification is
recorded as a failure of the current test case; the test method continues to
run, so one method can carry several independent checks.

| Method | Verifies |
|---|---|
| `verifyEqual(actual, expected)` | equality; `AbsTol`/`RelTol` accepted |
| `verifyEqualStructs(actual, expected)` | recursive struct/cell comparison with `AbsTol` |
| `verifyTrue(cond)`, `verifyFalse(cond)` | a condition |
| `verifyNumElements(value, n)` | the number of elements |
| `verifyNotEmpty(value)` | non-emptiness |
| `verifyGreaterThan(v, x)`, `verifyGreaterThanOrEqual(v, x)` | ordering |
| `verifyLessThan(v, x)` | ordering |

`verifyEqual` and `verifyEqualStructs` compare structs and nested cells
field by field and element by element, so whole trace structures can be
checked in one call:

```matlab
tc.verifyEqualStructs(p.data{1}, struct( ...
    "type", "scatter", ...
    "x", x, ...
    "y", y, ...
    "line", struct("color", OctaveTestCase.AnyColorString())), ...
    'AbsTol', 1e-15);
```

Any argument of an expected structure can be a wildcard matcher instead of a
concrete value:

- `OctaveTestCase.Any()` — matches anything.
- `OctaveTestCase.AnyColorString()` — any color string such as
  `'rgb(1,2,3)'`.
- `OctaveTestCase.AnyInteger()` / `OctaveTestCase.AnyNumber(positiveOnly)` —
  any integer or number.

Failures print the actual and expected values, the tolerance used, and the
`file:line` of the failing assertion.

## setUp / tearDown

Define `setUp` and/or `tearDown` methods to run code around every test case:

```matlab
classdef Test_db < OctaveTestCase
    methods
        function setUp(tc)
            tc.db = connect();
        end
        function tearDown(tc)
            close(tc.db);
        end
        function testQuery(tc)
            ...
        end
    end
end
```

Guarantees:

- `setUp` runs before every case, including every parameterized case.
- `tearDown` runs after every case, even when the test body or `setUp`
  threw.
- If `setUp` throws, the case is reported as errored, the body does not run,
  and `tearDown` still runs.
- Errors from `setUp`, the body, and `tearDown` all land in the case's
  error trace.

## Skipped tests

A test that returns early passes with zero verifications. Use this instead
of failing on unsupported engines.
