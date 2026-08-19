# Parameterized tests

A test method declares its argument values in comment lines directly above
the function line. Each annotation names one argument of the method (after
`tc`) and its possible values:

```matlab
classdef Test_quiver < OctaveTestCase
    methods
        % @quiverKind = {'vector', 'grid', 'nocoords'}
        function testHovertextData(tc, quiverKind)
            ...
        end
    end
end
```

The right-hand side is evaluated and must be a cell array of values (a
non-cell value is treated as a single-value list). With several annotations
the runner executes every cartesian combination as an isolated verdict:

```matlab
        % @color = {'red', 'blue'}
        % @n = {1, 2, 3}
        function testColors(tc, color, n)
```

runs six cases, each named after its values:

```
Test_quiver/testColors('red', 1)
Test_quiver/testColors('red', 2)
...
```

The annotation name must match the signature argument; a mismatch (wrong
name or count) is an error (`testParams:annotationName` /
`testParams:annotationCount`) that surfaces before anything runs.

## Running subsets

Targets are positional and accept any subset of the annotation values:

```
runoctests('Test_quiver/testHovertextData')              % all values
runoctests('Test_quiver/testHovertextData(''grid'')')    % one value
runoctests('Test_quiver/testHovertextData(,2)')          % first slot: all
runoctests('Test_quiver/testColors(''red'',)')           % second slot: all
runoctests('Test_quiver/testColors(''red'',3)')          % one combination
```

- An empty slot matches every annotated value for that argument.
- char and string values compare as equal, so the quote style in the target
  does not have to match the annotation.
- Commas inside quoted values are respected: `('a,b', 2)` is two values.
- A filter that matches no combination reports an errored SKIP verdict
  instead of failing the run.
- Parameters on a method with no annotation, or more values than the method
  takes arguments, throw before anything runs.

## Bare method names

A bare test method name resolves to its class when unambiguous:

```
runoctests('testHovertextData')
runoctests('testHovertextData(''grid'')')
```

The lookup scans every `Test_*.m` file under the test root. If the name is
defined by more than one class, the runner throws
`runoctests:ambiguousMethod` and lists the candidates.
