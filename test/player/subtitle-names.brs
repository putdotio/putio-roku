' Driver for the subtitle name cases in manifest-subtitles.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        input = cases[name]
        if input.kind = "label"
            results[name] = getCleanSubtitleName(input.name)
        else if input.kind = "labels"
            results[name] = getPutioSubtitleLabels(input.subtitles)
        else if input.kind = "menu" or input.kind = "manifestMenu"
            m.trackMenuMode = "captions"
            m.trackMenuItems = []
            m.selectedSubtitleTrackName = ""
            tracks = input.tracks
            if input.kind = "menu" then tracks = createSubtitleTracks(input.subtitles)
            addTrackMenuItems(tracks, true)
            labels = []
            for each item in getTrackMenuPresentationItems()
                labels.push(item.label)
            end for
            results[name] = labels
        else
            results[name] = subtitleTrackNamesMatch(input.left, input.right)
        end if
    end for

    return formatJson(results)
end function
