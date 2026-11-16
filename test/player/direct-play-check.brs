' Driver for direct-play-check.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        input = cases[name]
        probe = createFakeDecoderProbe(input.probe)
        verdict = checkDirectPlay(input.mediaInfo, probe)
        results[name] = { verdict: verdict, calls: probe.calls }
    end for

    return formatJson(results)
end function
