' Driver for playback-resolver.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        input = cases[name]
        ctx = input.ctx
        if ctx <> invalid and ctx.probe <> invalid
            ctx.probe = createFakeDecoderProbe(ctx.probe)
        end if
        if input.sameSourceAs <> invalid
            results[name] = resolveSameSourcePlaybackPlan(input.file, input.sameSourceAs, ctx)
        else
            results[name] = resolvePlaybackPlan(input.file, input.method, ctx)
        end if
    end for

    return formatJson(results)
end function
