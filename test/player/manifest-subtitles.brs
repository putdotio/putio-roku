' Driver for manifest-subtitles.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        matches = matchManifestSubtitles(cases[name].tracks, cases[name].subtitles)
        keys = []
        for each match in matches
            if match = invalid
                keys.push(invalid)
            else
                keys.push(match.key)
            end if
        end for
        results[name] = keys
    end for

    return formatJson(results)
end function
