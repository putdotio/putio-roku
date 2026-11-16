' Driver for playback-failure.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        results[name] = classifyPlaybackFailure(cases[name])
    end for

    return formatJson(results)
end function
