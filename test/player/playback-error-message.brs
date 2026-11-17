' Driver for playback-error-message.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        input = cases[name]
        if input.unplayable <> invalid and input.unplayable = true
            message = buildUnplayableDialogMessage(input.reason, input.method)
        else
            message = buildPlaybackErrorDialogMessage(input.reason, input.source)
        end if
        results[name] = {
            title: buildPlaybackErrorDialogTitle(input.reason),
            messageLines: message.split(chr(10)),
            buttons: getPlaybackErrorDialogButtons(getPlaybackErrorDialogActions(input.reason, input.method))
        }
    end for

    return formatJson(results)
end function
