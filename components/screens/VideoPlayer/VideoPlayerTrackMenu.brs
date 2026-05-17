sub showTrackMenu(mode)
    if mode = "audio"
        if m.audioTracks = invalid
            return
        end if

        if m.audioTracks.count() <= 1
            return
        end if
    else if mode = "captions"
        if m.subtitleTracks = invalid
            return
        end if

        if m.subtitleTracks.count() = 0
            return
        end if
    else if mode = "speed"
        if m.playbackSpeedSupported = false
            return
        end if
    end if

    m.trackMenuMode = mode
    m.trackMenuItems = []
    m.trackMenuReturnFocusIndex = m.focusIndex

    content = createObject("roSGNode", "ContentNode")

    if mode = "audio"
        m.trackMenuTitle.text = "Audio tracks"
        addTrackMenuItems(content, m.audioTracks, false)
    else if mode = "captions"
        m.trackMenuTitle.text = "Subtitles"
        addSubtitleOffItem(content)
        addTrackMenuItems(content, m.subtitleTracks, true)
    else if mode = "speed"
        m.trackMenuTitle.text = "Playback speed"
        addPlaybackSpeedMenuItems(content)
    end if

    if m.trackMenuItems.count() = 0
        addDisabledTrackMenuItem(content, "No tracks available")
    end if

    m.trackMenuFocusIndex = getSelectedTrackMenuIndex()
    m.trackMenuScrollOffset = 0
    ensureTrackMenuFocusVisible()
    renderTrackMenuRows()
    m.trackMenu.visible = true
    m.osd.visible = true
    m.osdTimer.control = "stop"
    updateTrackMenuFocus()
    m.canSelectTrackMenu = false
    m.trackMenuSelectionGuard.control = "stop"
    m.trackMenuSelectionGuard.control = "start"
end sub

sub onTrackMenuSelectionGuardFire()
    m.canSelectTrackMenu = true
end sub

sub renderTrackMenuRows()
    rowCount = getTrackMenuVisibleRowCount()
    metrics = getTrackMenuMetrics()

    panelHeight = metrics.topPadding + metrics.bottomPadding + (rowCount * metrics.rowHeight)
    if rowCount > 1
        panelHeight = panelHeight + ((rowCount - 1) * metrics.rowGap)
    end if

    if panelHeight < metrics.minPanelHeight
        panelHeight = metrics.minPanelHeight
    end if

    panelY = Int((1080 - panelHeight) / 2)
    if metrics.panelY <> invalid
        panelY = metrics.panelY
    end if

    m.trackMenuPanel.width = metrics.panelWidth
    m.trackMenuPanel.height = panelHeight
    m.trackMenuPanel.translation = [metrics.panelX, panelY]
    m.trackMenuTitle.width = metrics.titleWidth
    m.trackMenuTitle.translation = [metrics.titleX, m.trackMenuPanel.translation[1] + metrics.titleY]
    m.trackRows.translation = [metrics.rowsX, m.trackMenuPanel.translation[1] + metrics.rowsY]

    for i = 0 to m.trackMenuRows.count() - 1
        row = m.trackMenuRows[i]
        itemIndex = m.trackMenuScrollOffset + i
        row.node.translation = [0, i * (metrics.rowHeight + metrics.rowGap)]
        row.background.width = metrics.rowWidth
        row.background.height = metrics.rowHeight
        row.label.width = metrics.labelWidth
        row.check.translation = [metrics.checkX, metrics.checkY]

        if i < rowCount and itemIndex < m.trackMenuItems.count()
            row.node.visible = true
            row.label.text = getMenuSafeTrackLabel(m.trackMenuItems[itemIndex].label)
            if m.trackMenuMode = "captions"
                row.label.font = "font:SmallSystemFont"
                row.label.translation = [16, metrics.captionLabelY]
            else
                row.label.font = "font:MediumSystemFont"
                row.label.translation = [16, metrics.labelY]
            end if
        else
            row.node.visible = false
            row.label.text = ""
        end if
    end for
end sub

function getTrackMenuMetrics() as object
    return {
        panelWidth: 640,
        panelX: 640,
        titleWidth: 576,
        titleX: 672,
        rowsX: 672,
        rowWidth: 576,
        labelWidth: 500,
        checkX: 516,
        minPanelHeight: 284,
        titleY: 40,
        rowsY: 104,
        topPadding: 104,
        bottomPadding: 32,
        rowHeight: 70,
        rowGap: 8,
        labelY: 15,
        captionLabelY: 18,
        checkY: 10
    }
end function

sub addPlaybackSpeedMenuItems(content)
    for each speed in m.playbackSpeedOptions
        label = getPlaybackSpeedLabel(speed)
        item = content.createChild("ContentNode")
        item.title = label
        m.trackMenuItems.push({
            type: "speed",
            label: label,
            speed: speed
        })
    end for
end sub

sub addTrackMenuItems(content, tracks, isSubtitle)
    if tracks = invalid
        return
    end if

    for each track in tracks
        title = getTrackLabel(track)
        item = content.createChild("ContentNode")
        item.title = getMenuSafeTrackLabel(title)

        if isSubtitle
            m.trackMenuItems.push({
                type: "subtitle",
                label: title,
                trackName: readTrackValue(track, "TrackName"),
            })
        else
            m.trackMenuItems.push({
                type: "audio",
                label: title,
                track: readTrackValue(track, "Track"),
            })
        end if
    end for
end sub

sub addSubtitleOffItem(content)
    item = content.createChild("ContentNode")
    item.title = "Off"
    m.trackMenuItems.push({
        type: "subtitleOff",
        label: "Off"
    })
end sub

sub addDisabledTrackMenuItem(content, title)
    item = content.createChild("ContentNode")
    item.title = title
    m.trackMenuItems.push({
        type: "disabled",
        label: title
    })
end sub

sub moveTrackMenuFocus(direction)
    if m.trackMenu.visible = false
        return
    end if

    if m.trackMenuItems.count() = 0
        return
    end if

    m.trackMenuFocusIndex = m.trackMenuFocusIndex + direction

    if m.trackMenuFocusIndex < 0
        m.trackMenuFocusIndex = m.trackMenuItems.count() - 1
    else if m.trackMenuFocusIndex >= m.trackMenuItems.count()
        m.trackMenuFocusIndex = 0
    end if

    ensureTrackMenuFocusVisible()
    renderTrackMenuRows()
    updateTrackMenuFocus()
end sub

sub updateTrackMenuFocus()
    for i = 0 to m.trackMenuRows.count() - 1
        row = m.trackMenuRows[i]
        itemIndex = m.trackMenuScrollOffset + i
        focused = m.trackMenu.visible and itemIndex = m.trackMenuFocusIndex and row.node.visible
        selected = false

        if itemIndex < m.trackMenuItems.count()
            selected = isTrackMenuItemSelected(m.trackMenuItems[itemIndex])
        end if

        row.background.visible = focused
        row.check.visible = selected

        if focused
            row.label.color = "0xFFFFFFFF"
        else
            row.label.color = "0xE7E7E7FF"
        end if
    end for
end sub

function getTrackMenuVisibleRowCount() as integer
    rowCount = m.trackMenuItems.count()
    if rowCount > m.trackMenuRows.count()
        rowCount = m.trackMenuRows.count()
    end if

    maxVisibleRows = m.trackMenuRows.count()

    if rowCount > maxVisibleRows
        rowCount = maxVisibleRows
    end if

    return rowCount
end function

sub ensureTrackMenuFocusVisible()
    visibleRows = getTrackMenuVisibleRowCount()
    if visibleRows <= 0
        m.trackMenuScrollOffset = 0
        return
    end if

    if m.trackMenuFocusIndex < m.trackMenuScrollOffset
        m.trackMenuScrollOffset = m.trackMenuFocusIndex
    else if m.trackMenuFocusIndex >= m.trackMenuScrollOffset + visibleRows
        m.trackMenuScrollOffset = m.trackMenuFocusIndex - visibleRows + 1
    end if

    maxOffset = m.trackMenuItems.count() - visibleRows
    if maxOffset < 0
        maxOffset = 0
    end if

    if m.trackMenuScrollOffset > maxOffset
        m.trackMenuScrollOffset = maxOffset
    else if m.trackMenuScrollOffset < 0
        m.trackMenuScrollOffset = 0
    end if
end sub

function isTrackMenuItemSelected(item) as boolean
    if item = invalid
        return false
    end if

    if item.type = "audio"
        return m.selectedAudioTrack <> invalid and item.track <> invalid and item.track.toStr() = m.selectedAudioTrack.toStr()
    end if

    if item.type = "subtitleOff"
        return m.selectedSubtitleTrackName = invalid or m.selectedSubtitleTrackName = ""
    end if

    if item.type = "subtitle"
        return m.selectedSubtitleTrackName <> "" and item.trackName <> invalid and item.trackName.toStr() = m.selectedSubtitleTrackName
    end if

    if item.type = "speed"
        return item.label <> invalid and item.label = m.selectedPlaybackSpeedLabel
    end if

    return false
end function

function getSelectedTrackMenuIndex() as integer
    for i = 0 to m.trackMenuItems.count() - 1
        if isTrackMenuItemSelected(m.trackMenuItems[i])
            return i
        end if
    end for

    return 0
end function

sub selectFocusedTrackMenuItem()
    if m.trackMenu.visible = false or m.canSelectTrackMenu = false
        return
    end if

    index = m.trackMenuFocusIndex
    if index = invalid or m.trackMenuItems[index] = invalid
        return
    end if

    item = m.trackMenuItems[index]

    if item.type = "audio" and item.track <> invalid and m.video.hasField("audioTrack")
        m.userSelectedAudioTrack = true
        m.video.audioTrack = item.track.toStr()
        m.selectedAudioTrack = item.track
    else if item.type = "subtitle"
        if item.trackName <> invalid and item.trackName <> ""
            m.selectedSubtitleTrackName = item.trackName.toStr()
            applySubtitleSelection()
        end if
    else if item.type = "subtitleOff"
        m.selectedSubtitleTrackName = ""
        applySubtitleSelection()
    else if item.type = "speed"
        applyPlaybackSpeed(item)
    else
        return
    end if

    closeTrackMenu()
end sub

sub applyPlaybackSpeed(item)
    if m.playbackSpeedSupported = false or item = invalid or item.speed = invalid
        return
    end if

    wasPlaying = m.video.state = "playing" or m.video.state = "buffering"
    m.selectedPlaybackSpeed = item.speed
    m.selectedPlaybackSpeedLabel = getPlaybackSpeedLabel(item.speed)

    if wasPlaying
        m.video.control = "pause"
    end if

    enforcePlaybackSpeed()

    if wasPlaying
        m.video.control = "resume"
        enforcePlaybackSpeed()
    end if
end sub

sub enforcePlaybackSpeed()
    if m.playbackSpeedSupported = false
        return
    end if

    if m.selectedPlaybackSpeed = invalid
        return
    end if

    m.video.playbackSpeed = m.selectedPlaybackSpeed
end sub

function getPlaybackSpeedLabel(speed) as string
    if speed = 0.25
        return "0.25x"
    else if speed = 0.5
        return "0.5x"
    else if speed = 0.75
        return "0.75x"
    else if speed = 1
        return "1x"
    else if speed = 1.25
        return "1.25x"
    else if speed = 1.5
        return "1.5x"
    else if speed = 1.75
        return "1.75x"
    else if speed = 2
        return "2x"
    end if

    return speed.toStr() + "x"
end function

sub applySubtitleSelection()
    if m.selectedSubtitleTrackName <> invalid and m.selectedSubtitleTrackName <> ""
        selectedTrackName = getAvailableSubtitleTrackName(m.selectedSubtitleTrackName)
        m.selectedSubtitleTrackName = selectedTrackName
        m.video.globalCaptionMode = "On"
        m.video.subtitleTrack = selectedTrackName
    else
        m.video.globalCaptionMode = "Off"
        m.video.subtitleTrack = ""
    end if

    updateTrackControlIcons()
    updateControlFocus()
end sub

sub closeTrackMenu()
    m.trackMenu.visible = false
    m.canSelectTrackMenu = false
    m.trackMenuSelectionGuard.control = "stop"
    m.top.setFocus(true)
    m.focusArea = "controls"
    m.focusIndex = m.trackMenuReturnFocusIndex
    showOsd()
end sub

function getTrackLabel(track) as string
    name = readTrackValue(track, "Name")
    language = readTrackValue(track, "Language")

    if name <> invalid and name <> ""
        trackName = readTrackValue(track, "TrackName")
        description = readTrackValue(track, "Description")
        if trackName <> invalid and trackName <> "" and description <> invalid and description <> ""
            return name.toStr()
        end if

        if language <> invalid and language <> "" and language <> name
            return name.toStr() + " (" + language.toStr() + ")"
        end if

        return name.toStr()
    end if

    if language <> invalid and language <> ""
        return language.toStr()
    end if

    trackNumber = readTrackValue(track, "Track")
    if trackNumber <> invalid
        return "Track " + trackNumber.toStr()
    end if

    trackName = readTrackValue(track, "TrackName")
    if trackName <> invalid and trackName <> ""
        return trackName.toStr()
    end if

    description = readTrackValue(track, "Description")
    if description <> invalid and description <> ""
        return description.toStr()
    end if

    return "Unknown"
end function

function getMenuSafeTrackLabel(label) as string
    if label = invalid or label = ""
        return "Unknown"
    end if

    safeLabel = label.toStr()
    maxLength = 28
    if m.trackMenuMode = "captions"
        maxLength = 32
    else if m.trackMenuMode = "speed"
        maxLength = 12
    end if

    if Len(safeLabel) > maxLength
        return Left(safeLabel, maxLength - 3) + "..."
    end if

    return safeLabel
end function

function readTrackValue(track, key)
    if track <> invalid
        return track.lookupCI(key)
    end if

    return invalid
end function
