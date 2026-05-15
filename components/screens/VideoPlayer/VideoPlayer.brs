function init()
    m.top.focusable = true
    m.top.observeField("visible", "onVisibleChange")

    m.video = m.top.findNode("video")
    m.video.enableUI = false
    m.video.globalCaptionMode = "Off"

    m.osd = m.top.findNode("osd")
    m.osdTimer = m.top.findNode("osdTimer")
    m.osdTimer.observeField("fire", "onOsdTimerFire")

    m.title = m.top.findNode("title")
    m.trackSummary = m.top.findNode("trackSummary")
    m.positionLabel = m.top.findNode("position")
    m.durationLabel = m.top.findNode("duration")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.progressThumb = m.top.findNode("progressThumb")
    m.progressFocusTop = m.top.findNode("progressFocusTop")
    m.progressFocusBottom = m.top.findNode("progressFocusBottom")
    m.progressTrackWidth = 1728
    m.controlsGroup = m.top.findNode("controls")
    m.playbackSpeedSupported = m.video.hasField("playbackSpeed")

    m.trackMenu = m.top.findNode("trackMenu")
    m.trackMenuPanel = m.top.findNode("trackMenuPanel")
    m.trackMenuTitle = m.top.findNode("trackMenuTitle")
    m.trackMenuSelectionGuard = m.top.findNode("trackMenuSelectionGuard")
    m.trackMenuSelectionGuard.observeField("fire", "onTrackMenuSelectionGuardFire")
    m.trackMenuRows = []
    for i = 0 to 5
        index = i.toStr()
        m.trackMenuRows.push({
            node: m.top.findNode("trackRow" + index),
            background: m.top.findNode("trackRow" + index + "Background"),
            label: m.top.findNode("trackRow" + index + "Label"),
            check: m.top.findNode("trackRow" + index + "Check")
        })
    end for

    m.controls = [
        {
            node: m.top.findNode("rewindButton"),
            background: m.top.findNode("rewindBackground"),
            focusBar: m.top.findNode("rewindFocus"),
            icon: m.top.findNode("rewindIcon"),
            valueLabel: invalid,
            label: m.top.findNode("rewindLabel"),
            focusLabel: invalid,
            width: 88,
            action: "rewind",
            showFocusBackground: true,
            iconUri: "pkg:/images/icons/player-goback15.png",
            focusedIconUri: "pkg:/images/icons/player-goback15.png"
        },
        {
            node: m.top.findNode("playButton"),
            background: m.top.findNode("playBackground"),
            focusBar: m.top.findNode("playFocus"),
            icon: m.top.findNode("playIcon"),
            valueLabel: invalid,
            label: invalid,
            focusLabel: invalid,
            width: 88,
            action: "play",
            showFocusBackground: true,
            iconUri: "pkg:/images/icons/player-play.png",
            focusedIconUri: "pkg:/images/icons/player-play.png"
        },
        {
            node: m.top.findNode("fastForwardButton"),
            background: m.top.findNode("fastForwardBackground"),
            focusBar: m.top.findNode("fastForwardFocus"),
            icon: m.top.findNode("fastForwardIcon"),
            valueLabel: invalid,
            label: m.top.findNode("fastForwardLabel"),
            focusLabel: invalid,
            width: 88,
            action: "fastforward",
            showFocusBackground: true,
            iconUri: "pkg:/images/icons/player-goforward15.png",
            focusedIconUri: "pkg:/images/icons/player-goforward15.png"
        },
        {
            node: m.top.findNode("audioButton"),
            background: m.top.findNode("audioBackground"),
            focusBar: m.top.findNode("audioFocus"),
            icon: m.top.findNode("audioIcon"),
            valueLabel: invalid,
            label: invalid,
            focusLabel: m.top.findNode("audioFocusLabel"),
            width: 88,
            action: "audio",
            showFocusBackground: false,
            iconUri: "pkg:/images/icons/player-audio.png",
            focusedIconUri: "pkg:/images/icons/player-audio-focused.png"
        },
        {
            node: m.top.findNode("captionsButton"),
            background: m.top.findNode("captionsBackground"),
            focusBar: m.top.findNode("captionsFocus"),
            icon: m.top.findNode("captionsIcon"),
            valueLabel: invalid,
            label: invalid,
            focusLabel: m.top.findNode("captionsFocusLabel"),
            width: 88,
            action: "captions",
            showFocusBackground: false,
            iconUri: "pkg:/images/icons/player-captions.png",
            focusedIconUri: "pkg:/images/icons/player-captions-focused.png"
        },
        {
            node: m.top.findNode("speedButton"),
            background: m.top.findNode("speedBackground"),
            focusBar: m.top.findNode("speedFocus"),
            icon: invalid,
            valueLabel: m.top.findNode("speedText"),
            label: invalid,
            focusLabel: m.top.findNode("speedFocusLabel"),
            width: 88,
            action: "speed",
            showFocusBackground: false,
            iconUri: invalid,
            focusedIconUri: invalid
        }
    ]

    m.focusIndex = 1
    m.focusArea = "progress"
    m.progressReturnFocusIndex = 1
    m.duration = 0
    m.pendingSeekPosition = invalid
    m.seekInProgress = false
    m.seekValue = 0
    m.seekPressCount = 0
    m.seekDirection = 0
    m.wasPlayingBeforeSeek = false
    m.audioTracks = []
    m.rokuSubtitleTracks = []
    m.externalSubtitleTracks = []
    m.subtitleTracks = []
    m.trackMenuItems = []
    m.trackMenuMode = ""
    m.trackMenuFocusIndex = 0
    m.trackMenuScrollOffset = 0
    m.trackMenuReturnFocusIndex = 1
    m.selectedAudioTrack = invalid
    m.selectedSubtitleTrackName = ""
    m.playbackSpeedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
    m.selectedPlaybackSpeed = 1.0
    m.selectedPlaybackSpeedLabel = "1x"
    m.canSelectTrackMenu = false
end function

sub onVisibleChange()
    if m.top.visible
        m.video.notificationInterval = 1
        m.video.observeField("state", "onPlayerStateChanged")
        m.video.observeField("position", "onPlayerPositionChanged")
        m.video.observeField("duration", "onPlayerDurationChanged")
        m.video.observeField("availableAudioTracks", "onAvailableAudioTracksChanged")
        m.video.observeField("availableSubtitleTracks", "onAvailableSubtitleTracksChanged")

        setupPlayer()
        showOsd()
    else
        m.video.control = "stop"
        m.video.unobserveField("state")
        m.video.unobserveField("position")
        m.video.unobserveField("duration")
        m.video.unobserveField("availableAudioTracks")
        m.video.unobserveField("availableSubtitleTracks")
        m.osdTimer.control = "stop"
        m.trackMenuSelectionGuard.control = "stop"
        m.trackMenu.visible = false
    end if
end sub

sub setupPlayer()
    file = m.top.params.file
    videoContent = createObject("RoSGNode", "ContentNode")

    videoContent.url = getHlsStreamUrl(file)
    videoContent.title = file.name
    videoContent.streamformat = "hls"
    m.externalSubtitleTracks = createSubtitleTracks(m.top.params.subtitles)
    if m.externalSubtitleTracks.count() > 0
        videoContent.subtitletracks = m.externalSubtitleTracks
    end if

    m.title.text = file.name
    m.duration = getFileDuration(file)
    updateDurationLabel()
    syncSubtitleTracks()
    updateTrackSummary()

    m.video.content = videoContent
    applySubtitleSelection()
    startPlayback(m.top.params.startFrom)
end sub

function getHlsStreamUrl(file) as string
    return m.global.apiURL + "/files/" + file.id.toStr() + "/hls/media.m3u8?subtitle_key=all&max_subtitle_count=-1&oauth_token=" + m.global.user.download_token.toStr()
end function

function createSubtitleTracks(subtitles) as object
    tracks = []
    if subtitles = invalid
        return tracks
    end if

    for each subtitle in subtitles
        if subtitle <> invalid and subtitle.url <> invalid and subtitle.url <> ""
            tracks.push({
                Language: getSubtitleLanguageCode(subtitle),
                Name: getSubtitleLabel(subtitle),
                TrackName: subtitle.url,
                Description: subtitle.name
            })
        end if
    end for

    return tracks
end function

function getSubtitleLabel(subtitle) as string
    language = readTrackValue(subtitle, "language")
    name = readTrackValue(subtitle, "name")

    if language = invalid or language = ""
        language = readTrackValue(subtitle, "language_code")
    end if

    if language = invalid or language = ""
        language = "Custom"
    else
        language = language.toStr().replace("Undetermined", "Custom")
    end if

    if name <> invalid and name <> ""
        return language.toStr() + " - " + getCleanSubtitleName(name)
    end if

    return language.toStr()
end function

function getCleanSubtitleName(name) as string
    cleanName = name.toStr()
    cleanName = cleanName.replace(".srt", "")
    cleanName = cleanName.replace(".SRT", "")
    cleanName = cleanName.replace(".vtt", "")
    cleanName = cleanName.replace(".VTT", "")
    cleanName = cleanName.replace(".ass", "")
    cleanName = cleanName.replace(".ASS", "")
    cleanName = cleanName.replace(".ssa", "")
    cleanName = cleanName.replace(".SSA", "")

    return cleanName
end function

function getSubtitleLanguageCode(subtitle) as string
    languageCode = readTrackValue(subtitle, "language_code")
    if languageCode <> invalid and languageCode <> ""
        return languageCode.toStr()
    end if

    language = readTrackValue(subtitle, "language")
    if language <> invalid and language <> ""
        return language.toStr()
    end if

    return "und"
end function

function getFileDuration(file) as integer
    if file.video_metadata <> invalid and file.video_metadata.duration <> invalid
        return file.video_metadata.duration
    end if

    return 0
end function

sub startPlayback(time)
    if time = invalid
        time = 0
    end if

    m.video.control = "play"
    m.video.seek = time
    m.top.setFocus(true)
end sub

sub onPlayerStateChanged(obj)
    state = obj.getData()

    updatePlayIcon()

    if state = "error"
        onError()
    else if state = "finished"
        onGoBack()
    else if state = "buffering"
        showOsd()
    else
        restartOsdTimer()
    end if
end sub

sub onPlayerPositionChanged(obj)
    position = obj.getData()

    if m.seekInProgress
        if position <> invalid and m.global.user.settings.start_from = true
            saveVideoTime(position)
        end if

        return
    end if

    if position <> invalid
        if m.pendingSeekPosition <> invalid
            if Abs(position - m.pendingSeekPosition) <= 2
                m.pendingSeekPosition = invalid
            else if m.video.state = "playing"
                return
            end if
        end if

        m.positionLabel.text = getDurationString(position)
        updateProgress(position)
    else
        m.positionLabel.text = "..:.."
    end if

    if m.global.user.settings.start_from = true
        saveVideoTime(position)
    end if
end sub

sub onPlayerDurationChanged(obj)
    duration = obj.getData()

    if duration <> invalid and duration > 0
        m.duration = duration
        updateDurationLabel()
        updateProgress(getDisplayedPosition())
    end if
end sub

sub updateDurationLabel()
    if m.duration > 0
        m.durationLabel.text = getDurationString(m.duration)
    else
        m.durationLabel.text = "..:.."
    end if
end sub

sub updateProgress(position)
    fillWidth = 0

    if m.duration > 0 and position <> invalid
        fillWidth = Int((position / m.duration) * m.progressTrackWidth)

        if fillWidth < 0
            fillWidth = 0
        else if fillWidth > m.progressTrackWidth
            fillWidth = m.progressTrackWidth
        end if
    end if

    m.progressFill.width = fillWidth

    thumbWidth = m.progressThumb.width
    if thumbWidth = invalid or thumbWidth <= 0
        thumbWidth = 30
    end if

    thumbX = fillWidth - Int(thumbWidth / 2)
    if thumbX < 0
        thumbX = 0
    else if thumbX > m.progressTrackWidth - thumbWidth
        thumbX = m.progressTrackWidth - thumbWidth
    end if

    thumbHeight = m.progressThumb.height
    if thumbHeight = invalid or thumbHeight <= 0
        thumbHeight = thumbWidth
    end if

    trackY = m.progressTrack.translation[1]
    trackHeight = m.progressTrack.height
    thumbY = Int(trackY + (trackHeight / 2) - (thumbHeight / 2))
    if thumbY < 0
        thumbY = 0
    end if

    m.progressThumb.translation = [thumbX, thumbY]
end sub

sub onAvailableAudioTracksChanged(obj)
    tracks = obj.getData()
    if tracks <> invalid
        m.audioTracks = tracks
    else
        m.audioTracks = []
    end if

    if m.selectedAudioTrack = invalid and m.audioTracks.count() > 0
        m.selectedAudioTrack = readTrackValue(m.audioTracks[0], "Track")
    end if

    updateTrackSummary()
end sub

sub onAvailableSubtitleTracksChanged(obj)
    tracks = obj.getData()
    if tracks <> invalid
        m.rokuSubtitleTracks = tracks
    else
        m.rokuSubtitleTracks = []
    end if

    syncSubtitleTracks()
    updateTrackSummary()
end sub

sub syncSubtitleTracks()
    m.subtitleTracks = []
    if m.externalSubtitleTracks <> invalid and m.externalSubtitleTracks.count() > 0
        addUniqueSubtitleTracks(m.externalSubtitleTracks)
    else
        addUniqueSubtitleTracks(m.rokuSubtitleTracks)
    end if
end sub

sub addUniqueSubtitleTracks(tracks)
    if tracks = invalid
        return
    end if

    for each track in tracks
        trackName = readTrackValue(track, "TrackName")
        if trackName = invalid or trackName = "" or hasSubtitleTrack(trackName) = false
            m.subtitleTracks.push(track)
        end if
    end for
end sub

function hasSubtitleTrack(trackName) as boolean
    if trackName = invalid or trackName = ""
        return false
    end if

    for each track in m.subtitleTracks
        existingTrackName = readTrackValue(track, "TrackName")
        if existingTrackName <> invalid and existingTrackName.toStr() = trackName.toStr()
            return true
        end if
    end for

    return false
end function

sub updateTrackSummary()
    m.trackSummary.text = ""
    updateTrackControlVisibility()
end sub

sub updateTrackControlVisibility()
    hasAudioChoices = m.audioTracks <> invalid and m.audioTracks.count() > 1
    hasCaptionChoices = m.subtitleTracks <> invalid and m.subtitleTracks.count() > 0

    m.controls[3].node.visible = hasAudioChoices
    m.controls[4].node.visible = hasCaptionChoices
    m.controls[5].node.visible = m.playbackSpeedSupported

    updateControlLayout()
    ensureFocusedControlAvailable()
end sub

sub updateControlLayout()
    controlGap = 24
    transportWidth = (m.controls[0].width * 3) + (controlGap * 2)
    transportX = Int((1920 - transportWidth) / 2)

    for i = 0 to 2
        m.controls[i].node.translation = [transportX + (i * (m.controls[i].width + controlGap)), 0]
    end for

    auxiliaryWidth = getAuxiliaryControlsWidth(controlGap)

    nextX = 1824 - auxiliaryWidth
    for i = 3 to m.controls.count() - 1
        if isControlAvailable(i)
            m.controls[i].node.translation = [nextX, 0]
            nextX = nextX + m.controls[i].width + controlGap
        end if
    end for

    m.controlsGroup.translation = [0, 810]
end sub

function getAuxiliaryControlsWidth(controlGap as integer) as integer
    auxiliaryWidth = 0

    for i = 3 to m.controls.count() - 1
        if isControlAvailable(i)
            if auxiliaryWidth > 0
                auxiliaryWidth = auxiliaryWidth + controlGap
            end if

            auxiliaryWidth = auxiliaryWidth + m.controls[i].width
        end if
    end for

    return auxiliaryWidth
end function

sub showOsd()
    m.osd.visible = true
    ensureFocusedControlAvailable()
    updateControlFocus()
    restartOsdTimer()
end sub

sub hideOsd()
    if m.trackMenu.visible = false
        m.osd.visible = false
    end if
end sub

sub restartOsdTimer()
    m.osdTimer.control = "stop"

    if m.trackMenu.visible = false and m.video.state = "playing" and m.seekInProgress = false
        m.osdTimer.control = "start"
    end if
end sub

sub onOsdTimerFire()
    hideOsd()
end sub

sub updateControlFocus()
    ensureFocusedControlAvailable()

    for i = 0 to m.controls.count() - 1
        control = m.controls[i]

        focused = m.focusArea = "controls" and i = m.focusIndex and isControlAvailable(i)
        if focused and control.showFocusBackground = true
            control.background.visible = true
            control.focusBar.visible = false
        else
            control.background.visible = false
            control.focusBar.visible = false
        end if

        if control.iconUri <> invalid and control.focusedIconUri <> invalid
            if focused
                control.icon.uri = control.focusedIconUri
            else
                control.icon.uri = control.iconUri
            end if
        end if

        if control.label <> invalid
            control.label.visible = false
        end if

        if control.focusLabel <> invalid
            control.focusLabel.visible = m.focusArea = "controls" and i = m.focusIndex and isControlAvailable(i)
        end if

        if control.valueLabel <> invalid
            if focused
                control.valueLabel.color = "0xFDCE45FF"
            else
                control.valueLabel.color = "0xD6D6D6FF"
            end if
        end if
    end for

    progressFocused = m.focusArea = "progress"
    m.progressFocusTop.visible = progressFocused
    m.progressFocusBottom.visible = progressFocused
    updateProgressFocusStyle(progressFocused)
    updatePlayIcon()
end sub

sub updateProgressFocusStyle(focused as boolean)
    if focused
        m.progressTrack.translation = [0, 24]
        m.progressTrack.height = 10
        m.progressTrack.color = "0x7D7D7DE8"
        m.progressFill.translation = [0, 24]
        m.progressFill.height = 10
        m.progressFill.color = "0xFDCE45FF"
        m.progressFocusTop.width = 0
        m.progressFocusTop.height = 0
        m.progressFocusBottom.width = 0
        m.progressFocusBottom.height = 0
        m.progressThumb.uri = "pkg:/images/player-progress-thumb-focused.png"
        m.progressThumb.width = 30
        m.progressThumb.height = 30
        m.progressThumb.visible = true
    else
        m.progressTrack.translation = [0, 25]
        m.progressTrack.height = 8
        m.progressTrack.color = "0x5B5B5BE0"
        m.progressFill.translation = [0, 25]
        m.progressFill.height = 8
        m.progressFill.color = "0xD2A923FF"
        m.progressFocusTop.width = 0
        m.progressFocusTop.height = 0
        m.progressFocusBottom.width = 0
        m.progressFocusBottom.height = 0
        m.progressThumb.uri = "pkg:/images/player-progress-thumb.png"
        m.progressThumb.width = 18
        m.progressThumb.height = 18
        m.progressThumb.visible = m.seekInProgress
    end if

    updateProgress(getDisplayedPosition())
end sub

function isControlAvailable(index) as boolean
    if index < 0 or index >= m.controls.count()
        return false
    end if

    control = m.controls[index]
    if control.node <> invalid and control.node.visible = false
        return false
    end if

    return true
end function

sub ensureFocusedControlAvailable()
    if m.focusArea <> "controls"
        return
    end if

    if isControlAvailable(m.focusIndex)
        return
    end if

    if isControlAvailable(1)
        m.focusIndex = 1
        return
    end if

    for i = 0 to m.controls.count() - 1
        if isControlAvailable(i)
            m.focusIndex = i
            return
        end if
    end for
end sub

sub updatePlayIcon()
    playFocused = m.focusArea = "controls" and m.focusIndex = 1

    if m.video.state = "playing" or m.video.state = "buffering"
        if playFocused
            m.controls[1].icon.uri = "pkg:/images/icons/player-pause.png"
        else
            m.controls[1].icon.uri = "pkg:/images/icons/player-pause.png"
        end if
    else
        if playFocused
            m.controls[1].icon.uri = "pkg:/images/icons/player-play.png"
        else
            m.controls[1].icon.uri = "pkg:/images/icons/player-play.png"
        end if
    end if
end sub

sub moveFocus(direction)
    m.focusArea = "controls"

    for attempts = 0 to m.controls.count() - 1
        m.focusIndex = m.focusIndex + direction

        if m.focusIndex < 0
            m.focusIndex = m.controls.count() - 1
        else if m.focusIndex >= m.controls.count()
            m.focusIndex = 0
        end if

        if isControlAvailable(m.focusIndex)
            exit for
        end if
    end for

    m.progressReturnFocusIndex = m.focusIndex
    updateControlFocus()
    restartOsdTimer()
end sub

sub activateFocusedControl()
    if m.focusArea = "progress"
        if m.seekInProgress
            commitPreviewSeek()
        else
            playOrPause()
        end if
        return
    end if

    if isControlAvailable(m.focusIndex) = false
        return
    end if

    action = m.controls[m.focusIndex].action

    if action = "rewind"
        rewind()
    else if action = "play"
        playOrPause()
    else if action = "fastforward"
        fastforward()
    else if action = "audio"
        showTrackMenu("audio")
    else if action = "captions"
        showTrackMenu("captions")
    else if action = "speed"
        showTrackMenu("speed")
    end if
end sub

sub focusProgress()
    if m.focusArea = "controls" and isControlAvailable(m.focusIndex)
        m.progressReturnFocusIndex = m.focusIndex
    end if

    m.focusArea = "progress"
    updateControlFocus()
    restartOsdTimer()
end sub

sub focusControls()
    m.focusArea = "controls"
    m.focusIndex = m.progressReturnFocusIndex
    ensureFocusedControlAvailable()
    m.progressReturnFocusIndex = m.focusIndex
    updateControlFocus()
    restartOsdTimer()
end sub

sub playOrPause()
    if m.seekInProgress
        commitPreviewSeek()
        return
    end if

    if m.video.state = "playing" or m.video.state = "buffering"
        m.video.control = "pause"
    else
        m.video.control = "resume"
    end if

    showOsd()
end sub

sub rewind()
    focusProgress()
    seekBy(-15)
end sub

sub fastforward()
    focusProgress()
    seekBy(15)
end sub

sub seekBy(seconds)
    if m.seekInProgress
        resetPreviewSeek()
    end if

    nextPosition = getDisplayedPosition() + seconds

    if nextPosition < 0
        nextPosition = 0
    end if

    if m.duration > 0 and nextPosition > m.duration
        nextPosition = m.duration
    end if

    m.pendingSeekPosition = nextPosition
    m.positionLabel.text = getDurationString(nextPosition)
    updateProgress(nextPosition)
    m.video.seek = nextPosition
    showOsd()
end sub

sub previewSeekBy(seconds)
    startPreviewSeek(seconds)

    nextPosition = m.seekValue + getPreviewSeekDelta(seconds)

    if nextPosition < 0
        nextPosition = 0
    end if

    if m.duration > 0 and nextPosition > m.duration
        nextPosition = m.duration
    end if

    m.seekValue = nextPosition
    m.positionLabel.text = getDurationString(m.seekValue)
    updateProgress(m.seekValue)
    showOsd()
end sub

sub startPreviewSeek(seconds)
    direction = getSeekDirection(seconds)

    if m.seekInProgress = false
        m.seekValue = getDisplayedPosition()
        m.seekInProgress = true
        m.wasPlayingBeforeSeek = m.video.state = "playing" or m.video.state = "buffering"
        m.seekPressCount = 0
        m.seekDirection = direction

        if m.wasPlayingBeforeSeek
            m.video.control = "pause"
        end if
    else if direction <> m.seekDirection
        m.seekPressCount = 0
        m.seekDirection = direction
    end if
end sub

function getSeekDirection(seconds) as integer
    if seconds < 0
        return -1
    end if

    return 1
end function

function getPreviewSeekDelta(seconds) as integer
    m.seekPressCount = m.seekPressCount + 1
    stepSize = Abs(seconds)

    if stepSize < 15
        stepSize = 15
    end if

    delta = stepSize * m.seekPressCount

    if seconds < 0
        return -delta
    end if

    return delta
end function

function getDisplayedPosition() as integer
    if m.seekInProgress
        return m.seekValue
    end if

    if m.pendingSeekPosition <> invalid
        return m.pendingSeekPosition
    end if

    if m.video.position <> invalid
        return m.video.position
    end if

    return 0
end function

sub commitPreviewSeek()
    if m.seekInProgress = false
        return
    end if

    seekPosition = m.seekValue
    resetPreviewSeek()
    m.pendingSeekPosition = seekPosition
    m.positionLabel.text = getDurationString(seekPosition)
    updateProgress(seekPosition)
    m.video.seek = seekPosition

    if m.wasPlayingBeforeSeek
        m.video.control = "resume"
    end if

    showOsd()
end sub

sub cancelPreviewSeek()
    if m.seekInProgress = false
        return
    end if

    shouldResume = m.wasPlayingBeforeSeek
    resetPreviewSeek()
    m.positionLabel.text = getDurationString(getDisplayedPosition())
    updateProgress(getDisplayedPosition())

    if shouldResume
        m.video.control = "resume"
    end if

    showOsd()
end sub

sub resetPreviewSeek()
    m.seekInProgress = false
    m.seekPressCount = 0
    m.seekDirection = 0
end sub

sub seekToStart()
    resetPreviewSeek()
    m.pendingSeekPosition = 0
    m.positionLabel.text = getDurationString(0)
    updateProgress(0)
    m.video.seek = 0
    showOsd()
end sub

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
        m.trackMenuTitle.text = "Subtitle tracks"
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

    panelHeight = 168 + (rowCount * 92)
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
    m.trackMenuTitle.translation = [metrics.titleX, m.trackMenuPanel.translation[1] + 58]
    m.top.findNode("trackRows").translation = [metrics.rowsX, m.trackMenuPanel.translation[1] + 148]

    for i = 0 to m.trackMenuRows.count() - 1
        row = m.trackMenuRows[i]
        itemIndex = m.trackMenuScrollOffset + i
        row.background.width = metrics.rowWidth
        row.label.width = metrics.labelWidth
        row.check.translation = [metrics.checkX, 21]

        if i < rowCount and itemIndex < m.trackMenuItems.count()
            row.node.visible = true
            row.label.text = getMenuSafeTrackLabel(m.trackMenuItems[itemIndex].label)
            if m.trackMenuMode = "captions"
                row.label.font = "font:SmallSystemFont"
                row.label.translation = [28, 28]
            else
                row.label.font = "font:MediumSystemFont"
                row.label.translation = [28, 24]
            end if
        else
            row.node.visible = false
            row.label.text = ""
        end if
    end for
end sub

function getTrackMenuMetrics() as object
    if m.trackMenuMode = "captions"
        return {
            panelWidth: 1160,
            panelX: 280,
            titleWidth: 1040,
            titleX: 340,
            rowsX: 320,
            rowWidth: 1080,
            labelWidth: 948,
            checkX: 1008,
            minPanelHeight: 384
        }
    end if

    if m.trackMenuMode = "speed"
        return {
            panelWidth: 760,
            panelX: 580,
            titleWidth: 640,
            titleX: 640,
            rowsX: 620,
            rowWidth: 680,
            labelWidth: 548,
            checkX: 608,
            panelY: 180,
            minPanelHeight: 352
        }
    end if

    return {
        panelWidth: 760,
        panelX: 580,
        titleWidth: 640,
        titleX: 640,
        rowsX: 620,
        rowWidth: 680,
        labelWidth: 548,
        checkX: 608,
        minPanelHeight: 352
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

    maxVisibleRows = 4
    if m.trackMenuMode = "speed"
        maxVisibleRows = 5
    end if

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
        return m.selectedSubtitleTrackName = ""
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

    if item.type = "audio" and item.track <> invalid
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

    m.selectedPlaybackSpeed = item.speed
    m.selectedPlaybackSpeedLabel = getPlaybackSpeedLabel(item.speed)
    m.video.playbackSpeed = item.speed
    updatePlaybackSpeedLabel()
end sub

sub updatePlaybackSpeedLabel()
    speedLabel = m.top.findNode("speedText")
    if speedLabel <> invalid
        speedLabel.text = m.selectedPlaybackSpeedLabel
    end if
end sub

function getPlaybackSpeedLabel(speed) as string
    if speed = 0.5
        return "0.5x"
    else if speed = 0.75
        return "0.75x"
    else if speed = 1
        return "1x"
    else if speed = 1.25
        return "1.25x"
    else if speed = 1.5
        return "1.5x"
    else if speed = 2
        return "2x"
    else if speed = 3
        return "3x"
    end if

    return speed.toStr() + "x"
end function

sub applySubtitleSelection()
    if m.selectedSubtitleTrackName <> invalid and m.selectedSubtitleTrackName <> ""
        m.video.globalCaptionMode = "On"
        m.video.subtitleTrack = m.selectedSubtitleTrackName
    else
        m.video.subtitleTrack = ""
        m.video.globalCaptionMode = "Off"
    end if
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
    maxLength = 82
    if m.trackMenuMode = "captions"
        maxLength = 98
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

sub onError()
    m.errorDialog = createObject("roSGNode", "Dialog")
    m.errorDialog.title = "Video Error"
    m.errorDialog.message = m.video.errorMsg + chr(10) + "Code: " + m.video.errorCode.toStr()
    m.errorDialog.observeField("wasClosed", "onErrorDialogClosed")
    m.top.showDialog = m.errorDialog
end sub

sub onErrorDialogClosed()
    onGoBack()
end sub

sub saveVideoTime(time)
    if time > 0
        m.setStartFromTask = createObject("roSGNode", "HttpTask")
        m.setStartFromTask.url = ("/files/" + m.top.params.file.id.toStr() + "/start-from/set")
        m.setStartFromTask.method = "POST"
        m.setStartFromTask.body = { time: time }
        m.setStartFromTask.control = "RUN"
    end if
end sub

sub onGoBack()
    m.video.control = "stop"
    m.top.navigateBack = "true"
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.visible and press
        normalizedKey = LCase(key)

        if normalizedKey = "back"
            if m.trackMenu.visible
                closeTrackMenu()
            else if m.seekInProgress
                cancelPreviewSeek()
            else if m.osd.visible
                hideOsd()
            else
                onGoBack()
            end if
            return true
        end if

        if m.trackMenu.visible
            if normalizedKey = "up"
                moveTrackMenuFocus(-1)
            else if normalizedKey = "down"
                moveTrackMenuFocus(1)
            else if normalizedKey = "ok" or normalizedKey = "select"
                selectFocusedTrackMenuItem()
            else
                return false
            end if

            return true
        end if

        osdWasHidden = m.osd.visible = false

        if normalizedKey = "play" or normalizedKey = "playpause"
            playOrPause()
            return true
        else if normalizedKey = "pause"
            if m.seekInProgress
                cancelPreviewSeek()
            end if

            m.video.control = "pause"
            showOsd()
            return true
        else if normalizedKey = "rewind" or normalizedKey = "rev"
            rewind()
            return true
        else if normalizedKey = "fastforward" or normalizedKey = "fwd"
            fastforward()
            return true
        else if normalizedKey = "replay" or normalizedKey = "instantreplay"
            seekToStart()
            return true
        end if

        if normalizedKey = "left"
            if osdWasHidden
                rewind()
            else if m.focusArea = "progress"
                showOsd()
                previewSeekBy(-15)
            else
                showOsd()
                moveFocus(-1)
            end if
        else if normalizedKey = "right"
            if osdWasHidden
                fastforward()
            else if m.focusArea = "progress"
                showOsd()
                previewSeekBy(15)
            else
                showOsd()
                moveFocus(1)
            end if
        else if normalizedKey = "up"
            showOsd()
            if osdWasHidden
                focusProgress()
            else if m.focusArea = "controls"
                focusProgress()
            else
                focusProgress()
            end if
        else if normalizedKey = "down"
            showOsd()
            if osdWasHidden
                focusProgress()
            else if m.focusArea = "progress"
                focusControls()
            else
                focusControls()
            end if
        else if normalizedKey = "ok" or normalizedKey = "select"
            showOsd()
            if osdWasHidden
                focusProgress()
            else
                activateFocusedControl()
            end if
        else if normalizedKey = "options" or normalizedKey = "info"
            showOsd()
            if osdWasHidden
                focusProgress()
            end if
        else
            if m.osd.visible = false
                showOsd()
                return true
            end if

            return false
        end if

        return true
    end if

    return false
end function

sub getDurationString(seconds) as string
    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(seconds)

    hours = datetime.GetHours().ToStr()
    minutes = datetime.GetMinutes().ToStr()
    seconds = datetime.GetSeconds().ToStr()

    if Len(hours) = 1 then
        hours = "0" + hours
    end if
    if Len(minutes) = 1 then
        minutes = "0" + minutes
    end if
    if Len(seconds) = 1 then
        seconds = "0" + seconds
    end if

    if hours <> "00"
        return hours + ":" + minutes + ":" + seconds
    else
        return minutes + ":" + seconds
    end if
end sub
