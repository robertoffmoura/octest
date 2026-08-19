% VERIFY_TESTPARAMS  Standalone check of the parameterized-test machinery.
% Exercises the % @arg = {...} annotations and the
% 'Class/method(v1,,v3)' filter of runoctests.  Fully self-contained:
% the functions under test are embedded copies of
% src/testParams.m and of the parameter helpers in
% src/runoctests.m (keep them in sync when those change),
% and a minimal OctaveTestCase base class is written next to the scratch
% test classes, so no repo checkout is needed.
%
%   MATLAB:  matlab -batch "verify_testparams"   (or just verify_testparams)
%   Octave:  pkg load datatypes statistics; verify_testparams
%
% Prints PASS/FAIL per check and errors out on the first failure.

function verify_testparams()
    % scratch classes are classdef files, which both engines resolve by
    % name only from the path, so the scratch folder must be added;
    % cleanup at the end removes it again
    scratchDir = fullfile(tempdir, 'tparam_check');
    if exist(scratchDir, 'dir')
        rmdir(scratchDir, 's');
    end
    mkdir(scratchDir);
    writeScratchClasses(scratchDir);
    addpath(scratchDir);

    % 1. annotation parsing: 2 args, names a/b, cartesian product of 4
    [combos, argCount, argNames] = testParams(which('Test_paramcheck'), 'testTwo');
    check(argCount == 2, 'argCount == 2');
    check(isequal(argNames, {'a', 'b'}), 'argNames == {a, b}');
    check(numel(combos) == 4, 'cartesian product of 2x2 == 4 combos');

    % 2. no annotation -> {} / 0
    [combos0, n0] = testParams(which('Test_paramcheck'), 'testNoArgs');
    check(isempty(combos0) && n0 == 0, 'no-arg method has no combos');

    % 3. full run: all 4 combinations pass
    verdicts = tpRun('Test_paramcheck', 'testTwo');
    check(numel(verdicts) == 4 && all([verdicts.Passed]), 'full run: 4 Passed');

    % 4. verdict names carry the parameter values (from a failing case)
    verdicts = tpRun('Test_paramcheck', 'testLabel');
    check(sum([verdicts.Passed]) == 1 && sum(~[verdicts.Passed]) == 1, ...
        'one of two cases passes');
    v = verdicts(find(~[verdicts.Passed], 1));
    check(~isempty(strfind(v.Name, 'bad')), 'verdict name carries parameter value');

    % 5. filters: string filter, char filter (normalized), wildcard slot
    verdicts = tpRun('Test_paramcheck', 'testTwo', '"x",1');
    check(numel(verdicts) == 1 && verdicts(1).Passed, ...
        'filter ("x",1): 1 Passed (string)');
    verdicts = tpRun('Test_paramcheck', 'testTwo', '''x'',1');
    check(numel(verdicts) == 1 && verdicts(1).Passed, ...
        'filter (''x'',1): 1 Passed (char, normalized)');
    verdicts = tpRun('Test_paramcheck', 'testTwo', ',2');
    check(numel(verdicts) == 2 && all([verdicts.Passed]), ...
        'wildcard first slot (,2): 2 Passed');

    % 6. no match -> SKIP verdict, not a crash
    verdicts = tpRun('Test_paramcheck', 'testTwo', '"z",1');
    check(numel(verdicts) == 1 && verdicts(1).Errored && ~verdicts(1).Passed, ...
        'no matching combination reports Errored');

    % 7. params on a no-arg method -> throws
    checkThrows(@() tpRun('Test_paramcheck', 'testNoArgs', '1'), ...
        'runoctests:paramsOnNoArgMethod', ...
        'params on no-arg method throws paramsOnNoArgMethod');

    % 8. too many values -> throws
    checkThrows(@() tpRun('Test_paramcheck', 'testTwo', '1,2,3'), ...
        'runoctests:tooManyParams', ...
        'too many values throws tooManyParams');

    % 9. annotation/signature name mismatch -> throws
    checkThrows(@() testParams(which('Test_badparam'), 'testBad'), ...
        'testParams:annotationName', ...
        'annotation/signature mismatch throws testParams:annotationName');

    % 10. setUp/tearDown run around every case
    verdicts = tpRun('Test_setupcheck', 'testA');
    check(numel(verdicts) == 1 && ~verdicts(1).Errored && verdicts(1).Passed, ...
        'setUp/tearDown around a plain test');
    verdicts = tpRun('Test_setupcheck', 'testParam');
    check(sum(~[verdicts.Errored] & [verdicts.Passed]) == 1 && ...
        sum([verdicts.Errored]) == 1, ...
        'setUp runs per parameterized case');
    verdicts = tpRun('Test_setupcheck', 'testThrows');
    check(numel(verdicts) == 1 && verdicts(1).Errored && ...
        ~isempty(strfind(verdicts(1).ErrorTrace, 'tearDown ran after throw')), ...
        'tearDown runs after a throwing body');

    % cleanup
    rmpath(scratchDir);
    rmdir(scratchDir, 's');
    fprintf('verify_testparams: ALL CHECKS PASSED\n');
end

function writeScratchClasses(scratchDir)
    % minimal OctaveTestCase: enough for the scratch tests and for the
    % condensed runner (startTest/finishTest/recordPass/recordFail)
    fid = fopen(fullfile(scratchDir, 'OctaveTestCase.m'), 'w');
    fprintf(fid, '%s\n', ...
        "classdef OctaveTestCase < handle", ...
        "    properties", ...
        "        CurrentTest = ''", ...
        "        Passed = 0", ...
        "        Failed = 0", ...
        "        Failures = {}", ...
        "        TestVerdicts = []", ...
        "        ErrorTrace = ''", ...
        "    end", ...
        "    properties (Access = private)", ...
        "        p_curFailed = 0", ...
        "        p_curDiagnostics = {}", ...
        "    end", ...
        "    methods", ...
        "        function startTest(testCase, name)", ...
        "            testCase.CurrentTest = name;", ...
        "            testCase.p_curFailed = 0;", ...
        "            testCase.p_curDiagnostics = {};", ...
        "            testCase.ErrorTrace = '';", ...
        "        end", ...
        "        function v = finishTest(testCase)", ...
        "            v = struct('Name', testCase.CurrentTest, ...", ...
        "                'Passed', testCase.p_curFailed == 0, ...", ...
        "                'VerificationFailures', testCase.p_curFailed, ...", ...
        "                'Diagnostics', {testCase.p_curDiagnostics}, ...", ...
        "                'ErrorTrace', testCase.ErrorTrace, 'Duration', 0, 'Errored', false);", ...
        "            if isempty(testCase.TestVerdicts)", ...
        "                testCase.TestVerdicts = v;", ...
        "            else", ...
        "                testCase.TestVerdicts(end + 1) = v;", ...
        "            end", ...
        "        end", ...
        "        function recordPass(testCase)", ...
        "            testCase.Passed = testCase.Passed + 1;", ...
        "        end", ...
        "        function recordFail(testCase, diagnostic)", ...
        "            testCase.Failed = testCase.Failed + 1;", ...
        "            testCase.p_curFailed = testCase.p_curFailed + 1;", ...
        "            testCase.p_curDiagnostics{end + 1} = diagnostic;", ...
        "        end", ...
        "        function verifyTrue(testCase, condition, diagnostic)", ...
        "            if nargin < 3, diagnostic = ''; end", ...
        "            if condition", ...
        "                testCase.recordPass();", ...
        "            else", ...
        "                testCase.recordFail(diagnostic);", ...
        "            end", ...
        "        end", ...
        "        function verifyEqual(testCase, actual, expected)", ...
        "            if isequal(actual, expected) || isequaln(actual, expected)", ...
        "                testCase.recordPass();", ...
        "            else", ...
        "                testCase.recordFail('Values are not equal.');", ...
        "            end", ...
        "        end", ...
        "    end", ...
        "end");
    fclose(fid);

    fid = fopen(fullfile(scratchDir, 'Test_paramcheck.m'), 'w');
    fprintf(fid, '%s\n', ...
        'classdef Test_paramcheck < OctaveTestCase', ...
        '    methods', ...
        '        % @a = {"x", "y"}', ...
        '        % @b = {1, 2}', ...
        '        function testTwo(tc, a, b)', ...
        '            tc.verifyTrue(ischar(a) || strcmp(class(a), ''string''));', ...
        '            tc.verifyTrue(isnumeric(b) && isscalar(b));', ...
        '            tc.recordPass();', ...
        '        end', ...
        '', ...
        '        % @a = {"ok", "bad"}', ...
        '        function testLabel(tc, a)', ...
        '            tc.verifyEqual(char(a), ''ok'');', ...
        '        end', ...
        '', ...
        '        function testNoArgs(tc)', ...
        '            tc.recordPass();', ...
        '        end', ...
        '    end', ...
        'end');
    fclose(fid);

    fid = fopen(fullfile(scratchDir, 'Test_badparam.m'), 'w');
    fprintf(fid, '%s\n', ...
        'classdef Test_badparam < OctaveTestCase', ...
        '    methods', ...
        '        % @wrongname = {"x"}', ...
        '        function testBad(tc, rightname)', ...
        '            tc.recordPass();', ...
        '        end', ...
        '    end', ...
        'end');
    fclose(fid);

    fid = fopen(fullfile(scratchDir, 'Test_setupcheck.m'), 'w');
    fprintf(fid, '%s\n', ...
        'classdef Test_setupcheck < OctaveTestCase', ...
        '    methods', ...
        '        function setUp(tc)', ...
        '            if ~isempty(strfind(tc.CurrentTest, ''bad''))', ...
        '                error(''probe:setupboom'', ''setUp boom for bad case'');', ...
        '            end', ...
        '        end', ...
        '        function tearDown(tc)', ...
        '            if ~isempty(strfind(tc.CurrentTest, ''testThrows''))', ...
        '                error(''probe:tearAfterThrow'', ''tearDown ran after throw'');', ...
        '            end', ...
        '        end', ...
        '        function testA(tc)', ...
        '            tc.recordPass();', ...
        '        end', ...
        '        % @k = {"ok", "bad"}', ...
        '        function testParam(tc, k)', ...
        '            tc.recordPass();', ...
        '        end', ...
        '        function testThrows(tc)', ...
        '            error(''probe:boom'', ''boom'');', ...
        '        end', ...
        '    end', ...
        'end');
    fclose(fid);
end

function verdicts = tpRun(className, methodName, rawParams)
    % condensed copy of runoctests' per-method loop: reads the
    % annotations, applies the optional filter, runs one isolated case
    % per combination and returns the verdicts
    if nargin < 3
        rawParams = '';
    end
    tc = feval(className);
    classMeths = methods(tc);
    hasSetup = ismember('setUp', classMeths);
    hasTearDown = ismember('tearDown', classMeths);
    [combos, argCount] = testParams(which(className), methodName);
    args = struct('value', {}, 'wildcard', {});
    if ~isempty(rawParams)
        args = parseParamList(rawParams);
        if argCount == 0
            error('runoctests:paramsOnNoArgMethod', ...
                'Test method %s/%s takes no arguments but parameters (%s) were given.', ...
                className, methodName, rawParams);
        end
        if numel(args) > argCount
            error('runoctests:tooManyParams', ...
                'Test method %s/%s takes %d argument(s) but %d value(s) (%s) were given.', ...
                className, methodName, argCount, numel(args), rawParams);
        end
        combos = filterCombos(combos, args);
        if isempty(combos)
            verdicts = struct('Name', ...
                sprintf('%s/%s(%s)', className, methodName, rawParams), ...
                'Passed', false, 'VerificationFailures', 1, ...
                'Diagnostics', {sprintf( ...
                'No parameterization of %s matches (%s).', methodName, rawParams)}, ...
                'ErrorTrace', '', 'Duration', 0, 'Errored', true);
            return;
        end
    end
    if isempty(combos)
        combos = {{}};
    end

    verdicts = struct('Name', {}, 'Passed', {}, 'VerificationFailures', {}, ...
        'Diagnostics', {}, 'ErrorTrace', {}, 'Duration', {}, 'Errored', {});
    for ci = 1:numel(combos)
        combo = combos{ci};
        if isempty(combo)
            caseName = [className '/' methodName];
        else
            labels = cellfun(@valueLabel, combo, 'UniformOutput', false);
            caseName = sprintf('%s/%s(%s)', className, methodName, ...
                strjoin(labels, ', '));
        end
        tc.startTest(caseName);
        fname = str2func(methodName);
        threw = false;
        trace = '';
        % sequential try/catch blocks (Octave has no finally): setUp,
        % then the test, then tearDown regardless of what threw
        setUpOk = true;
        if hasSetup
            try
                tc.setUp();
            catch e
                threw = true;
                trace = e.message;
                setUpOk = false;
            end
        end
        if setUpOk
            try
                fname(tc, combo{:});
            catch e
                threw = true;
                trace = e.message;
            end
        end
        if hasTearDown
            try
                tc.tearDown();
            catch e
                threw = true;
                if isempty(trace)
                    trace = e.message;
                else
                    trace = [trace sprintf('\n\n') e.message];
                end
            end
        end
        tc.ErrorTrace = trace;
        v = tc.finishTest();
        v.Errored = threw;
        verdicts(end+1) = v; %#ok<AGROW>
    end
end

function [combos, argCount, argNames] = testParams(classFile, methodName)
    % embedded copy of src/testParams.m
    combos = {};
    argCount = 0;
    argNames = {};

    if isempty(classFile) || ~exist(classFile, 'file')
        return;
    end
    fid = fopen(classFile, 'r');
    if fid < 0
        return;
    end
    text = fread(fid, Inf, '*char')';
    fclose(fid);
    lines = strsplit(text, sprintf('\n'));

    namePat = ['^\s*function\s+' regexptranslate('escape', methodName) '\s*\('];
    methodLine = [];
    for i = 1:numel(lines)
        if ~isempty(regexp(lines{i}, namePat, 'once'))
            methodLine = i;
            break;
        end
    end
    if isempty(methodLine)
        return;
    end

    annNames = {};
    annExprs = {};
    j = methodLine - 1;
    while j >= 1
        line = lines{j};
        if isempty(strtrim(line))
            j = j - 1;
            continue;
        end
        tok = regexp(line, '^\s*%\s*@([A-Za-z_]\w*)\s*=\s*(.*)$', ...
            'tokens', 'once');
        if isempty(tok)
            break;
        end
        annNames{end + 1} = tok{1}; %#ok<AGROW>
        annExprs{end + 1} = strtrim(tok{2}); %#ok<AGROW>
        j = j - 1;
    end
    annNames = fliplr(annNames);
    annExprs = fliplr(annExprs);
    if isempty(annNames)
        return;
    end

    sigTok = regexp(lines{methodLine}, 'function\s+\w+\s*\((.*)\)', ...
        'tokens', 'once');
    sigNames = {};
    if ~isempty(sigTok)
        parts = strsplit(sigTok{1}, ',');
        for p = 1:numel(parts)
            part = strtrim(parts{p});
            eq = strfind(part, '=');
            if ~isempty(eq)
                part = strtrim(part(1:eq(1) - 1));
            end
            if ~isempty(part)
                sigNames{end + 1} = part; %#ok<AGROW>
            end
        end
    end
    if numel(sigNames) >= 2 && strcmp(sigNames{1}, 'tc')
        sigNames = sigNames(2:end);
    else
        sigNames = {};
    end
    if ~isempty(sigNames) && ~any(strcmp(sigNames, 'varargin'))
        if numel(sigNames) ~= numel(annNames)
            error('testParams:annotationCount', ...
                ['Method %s declares %d parameter annotation(s) but its ' ...
                 'signature takes %d argument(s) (after tc).'], ...
                methodName, numel(annNames), numel(sigNames));
        end
        for i = 1:numel(annNames)
            if ~strcmp(annNames{i}, sigNames{i})
                error('testParams:annotationName', ...
                    ['Annotation %d of %s is ''@%s'' but the signature ' ...
                     'argument %d is ''%s''.'], ...
                    i, methodName, annNames{i}, i, sigNames{i});
            end
        end
    end

    lists = cell(1, numel(annNames));
    for i = 1:numel(annNames)
        try
            v = eval(annExprs{i});
        catch e
            error('testParams:evalFailed', ...
                'Cannot evaluate annotation @%s = %s of %s: %s', ...
                annNames{i}, annExprs{i}, methodName, e.message);
        end
        if ~iscell(v)
            v = {v};
        end
        if isempty(v)
            error('testParams:noValues', ...
                'Annotation @%s of %s has no values.', annNames{i}, methodName);
        end
        lists{i} = v;
    end

    total = prod(cellfun(@numel, lists));
    combos = cell(total, 1);
    for c = 1:total
        idx = zeros(1, numel(lists));
        rem = c - 1;
        for j = 1:numel(lists)
            nj = numel(lists{j});
            idx(j) = mod(rem, nj) + 1;
            rem = floor(rem / nj);
        end
        combo = cell(1, numel(lists));
        for j = 1:numel(lists)
            combo{j} = lists{j}{idx(j)};
        end
        combos{c} = combo;
    end
    argCount = numel(annNames);
    argNames = annNames;
end

function args = parseParamList(raw)
    % embedded copy of runoctests' parseParamList
    args = struct('value', {}, 'wildcard', {});
    tokens = splitOnCommas(raw);
    for i = 1:numel(tokens)
        tok = strtrim(tokens{i});
        if isempty(tok)
            args(end+1) = struct('value', [], 'wildcard', true); %#ok<AGROW>
        else
            try
                v = eval(tok);
            catch e
                error('runoctests:badParamValue', ...
                    'Cannot evaluate parameter value ''%s'': %s', tok, e.message);
            end
            args(end+1) = struct('value', v, 'wildcard', false); %#ok<AGROW>
        end
    end
end

function tokens = splitOnCommas(raw)
    % embedded copy of runoctests' splitOnCommas
    tokens = {};
    start = 1;
    q = 0; % current quote character: 0 outside a literal, else ' or "
    i = 1;
    while i <= numel(raw)
        c = raw(i);
        if q == 0
            if c == '''' || c == '"'
                q = c;
            elseif c == ','
                tokens{end+1} = raw(start:i-1); %#ok<AGROW>
                start = i + 1;
            end
        else
            if c == q
                if i + 1 <= numel(raw) && raw(i+1) == q
                    i = i + 1;
                else
                    q = 0;
                end
            end
        end
        i = i + 1;
    end
    tokens{end+1} = raw(start:end);
end

function combos = filterCombos(combos, args)
    % embedded copy of runoctests' filterCombos
    if isempty(args)
        return;
    end
    keep = false(1, numel(combos));
    for c = 1:numel(combos)
        combo = combos{c};
        ok = true;
        for j = 1:numel(args)
            if args(j).wildcard
                continue;
            end
            if j > numel(combo) || ~paramEqual(combo{j}, args(j).value)
                ok = false;
                break;
            end
        end
        keep(c) = ok;
    end
    combos = combos(keep);
end

function ok = paramEqual(a, b)
    % embedded copy of runoctests' paramEqual, with isstring()
    % replaced by a class-name check so no package is needed
    if (ischar(a) || strcmp(class(a), 'string')) && ...
            (ischar(b) || strcmp(class(b), 'string'))
        ok = strcmp(char(a), char(b));
    else
        ok = isequal(a, b);
    end
end

function s = valueLabel(v)
    % embedded copy of runoctests' valueLabel, with isstring()
    % replaced by a class-name check so no package is needed
    if ischar(v)
        s = sprintf('''%s''', v);
    elseif strcmp(class(v), 'string') && isscalar(v)
        s = sprintf('"%s"', char(v));
    elseif isnumeric(v) && isscalar(v)
        s = strtrim(sprintf('%.17g', v));
    elseif islogical(v) && isscalar(v)
        if v, s = 'true'; else, s = 'false'; end
    else
        s = sprintf('%s', class(v));
    end
end

function checkThrows(fn, id, label)
    threw = false;
    try
        fn();
    catch e
        threw = strcmp(e.identifier, id);
    end
    check(threw, label);
end

function check(cond, label)
    if cond
        fprintf('PASS  %s\n', label);
    else
        error('verify_testparams:fail', 'FAIL  %s', label);
    end
end
