function main() as string
    results = {}
    cases = driverCases()
    for each name in cases
        input = cases[name]
        if input.kind = "label"
            results[name] = getCleanSubtitleName(input.name)
        else if input.kind = "labels"
            labels = []
            for each subtitle in input.subtitles
                labels.push(getPutioSubtitleLabel(subtitle, getPutioSubtitleLanguage(subtitle)))
            end for
            results[name] = getUniqueSubtitleLabels(labels)
        else if input.kind = "menu" or input.kind = "manifestMenu" or input.kind = "mixedMenu"
            m.trackMenuMode = "captions"
            m.trackMenuItems = []
            m.selectedSubtitleTrackName = input.selectedTrackName
            if m.selectedSubtitleTrackName = invalid then m.selectedSubtitleTrackName = ""
            addSubtitleOffItem()
            if input.kind = "menu"
                tracks = createSubtitleTracks(input.subtitles)
            else if input.kind = "mixedMenu"
                m.usesManifestSubtitles = false
                m.rokuSubtitleTracks = input.tracks
                m.externalSubtitleTracks = createSubtitleTracks(input.subtitles)
                syncSubtitleTracks()
                tracks = m.subtitleTracks
            else
                m.rokuSubtitleTracks = input.tracks
                m.externalSubtitleTracks = []
                m.subtitleTracks = []
                addManifestSubtitleTracks()
                tracks = m.subtitleTracks
            end if
            addTrackMenuItems(tracks, true)
            items = getTrackMenuPresentationItems()
            if input.keepLanguage <> true
                for each item in items
                    item.delete("captionLanguage")
                end for
            end if
            results[name] = items
        else if input.kind = "render"
            results[name] = renderMenuLabels(input.items)
        else
            results[name] = subtitleTrackNamesMatch(input.left, input.right)
        end if
    end for

    return formatJson(results)
end function

function renderMenuLabels(items as object) as object
    label = createObject("roSGNode", "Label")
    if not label.hasField("leadingEllipsis") then label.addField("leadingEllipsis", "boolean", false)
    rows = []
    for each item in items
        applyTrackMenuItemLabel(label, item)
        rows.push({
            text: label.text,
            leadingEllipsis: label.leadingEllipsis,
            ellipsisText: label.ellipsisText
        })
    end for
    return rows
end function
