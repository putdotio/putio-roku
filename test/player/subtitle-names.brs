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
            if input.selectedTrackName <> invalid then m.selectedSubtitleTrackName = input.selectedTrackName
            tracks = input.tracks
            if input.kind = "menu" then tracks = createSubtitleTracks(input.subtitles)
            addTrackMenuItems(tracks, true)
            items = getTrackMenuPresentationItems()
            if input.kind = "manifestMenu"
                results[name] = items
            else
                labels = []
                for each item in items
                    labels.push(item.label)
                end for
                results[name] = labels
            end if
        else
            results[name] = subtitleTrackNamesMatch(input.left, input.right)
        end if
    end for

    return formatJson(results)
end function
