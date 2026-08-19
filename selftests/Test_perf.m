classdef Test_perf < OctavePerfTestCase
    % keepMeasuring behavior tests: minimum samples, early stop once
    % the margin of error is met, the MaxSamples cap under noisy
    % workloads, and partial samples surviving a mid-loop throw.
    properties
        nRuns = 0
        injectNoise = false
        throwAt = 0
    end
    methods
        function testStableStopsEarly(tc)
            while tc.keepMeasuring
                tc.nRuns = tc.nRuns + 1;
                sqrt(1:1e7);
            end
            tc.verifyGreaterThanOrEqual(tc.nRuns, tc.NumWarmups + tc.MinSamples);
            tc.verifyLessThan(tc.p_nSamples, 50);
        end

        function testNoisyReachesCap(tc)
            % alternating an instant iteration with a 30 ms pause keeps
            % the relative margin far above 5% on any machine, so
            % sampling must run until the MaxSamples cap
            tc.injectNoise = true;
            startRuns = tc.nRuns;
            while tc.keepMeasuring
                tc.nRuns = tc.nRuns + 1;
                if tc.injectNoise && mod(tc.nRuns, 2) == 0
                    pause(0.03);
                end
            end
            tc.verifyEqual(tc.p_nSamples, tc.MaxSamples);
            tc.verifyEqual(tc.nRuns - startRuns, tc.NumWarmups + tc.MaxSamples);
        end

        function testThrowsMidLoopKeepsPartialSamples(tc)
            tc.throwAt = 8;
            startRuns = tc.nRuns;
            threw = false;
            try
                while tc.keepMeasuring
                    tc.nRuns = tc.nRuns + 1;
                    sqrt(1:1e7);
                    if tc.throwAt > 0 && tc.nRuns - startRuns == tc.throwAt
                        error('Test_perf:boom', 'boom mid-loop');
                    end
                end
            catch e
                threw = strcmp(e.identifier, 'Test_perf:boom');
            end
            tc.verifyTrue(threw, 'the body error propagates');
            tc.verifyTrue(tc.p_nSamples > 0, ...
                'partial samples remain available after the throw');
        end
    end
end
