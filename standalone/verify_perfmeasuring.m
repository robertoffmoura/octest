% VERIFY_PERFMEASURING  Standalone check of the keepMeasuring sampling
% logic.  The measured-loop logic is an embedded copy of
% OctavePerfTestCase.keepMeasuring (keep it in sync when that changes);
% no repo is needed.
%
%   MATLAB:  verify_perfmeasuring
%   Octave:  pkg load statistics; verify_perfmeasuring
%
% Prints PASS/FAIL per check and errors out on the first failure.

function verify_perfmeasuring()
    NumWarmups = 5;
    MinSamples = 4;
    MaxSamples = 256;
    RelativeMarginOfError = 0.05;
    ConfidenceLevel = 0.95;

    % 1. stable workload: stops as soon as the margin of error is met
    s = runScenario(1, 1e7, false, NumWarmups, MinSamples, MaxSamples, ...
        RelativeMarginOfError, ConfidenceLevel);
    check(s.nRuns >= NumWarmups + MinSamples, ...
        'stable workload runs warmups plus minimum samples');
    check(s.nSamples < 50, 'stable workload stops well below the cap');

    % 2. bimodal workload: margin never falls below 5%, cap is reached
    s = runScenario(1, 1e7, true, NumWarmups, MinSamples, MaxSamples, ...
        RelativeMarginOfError, ConfidenceLevel);
    check(s.nSamples == MaxSamples, 'noisy workload reaches the cap');
    check(s.nRuns == NumWarmups + MaxSamples, ...
        'one body run per warmup and sample');

    fprintf('verify_perfmeasuring: ALL CHECKS PASSED\n');
end

function s = runScenario(n, workload, noisy, NumWarmups, MinSamples, ...
        MaxSamples, RelativeMarginOfError, ConfidenceLevel)
    s.nRuns = 0;
    timer = tic;
    times = zeros(1, MaxSamples);
    nSamples = 0;
    warmupsDone = 0;
    first = true;
    ok = true;
    while ok
        if ~first
            dt = toc(timer);
            timer = tic;
            if warmupsDone < NumWarmups
                warmupsDone = warmupsDone + 1;
            else
                nSamples = nSamples + 1;
                times(nSamples) = dt;
                if nSamples >= MinSamples && nSamples < MaxSamples
                    m = mean(times(1:nSamples));
                    if m > 0
                        T = tQuantile(ConfidenceLevel, nSamples - 1);
                        relMoE = T * std(times(1:nSamples)) / (m * sqrt(nSamples));
                        if relMoE <= RelativeMarginOfError
                            ok = false;
                        end
                    end
                elseif nSamples >= MaxSamples
                    ok = false;
                end
            end
        else
            timer = tic;
            first = false;
        end
        if ~ok
            break;
        end
        s.nRuns = s.nRuns + 1;
        if noisy && mod(s.nRuns, 2) == 0
            pause(0.05);
        else
            sqrt(1:workload);
        end
    end
    s.nSamples = nSamples;
end

function T = tQuantile(confidence, dof)
    if exist('tinv')
        try
            T = tinv(1 - (1 - confidence) / 2, dof);
            return;
        catch
        end
    end
    T = 1.96;
end

function check(cond, label)
    if cond
        fprintf('PASS  %s\n', label);
    else
        error('verify_perfmeasuring:fail', 'FAIL  %s', label);
    end
end
