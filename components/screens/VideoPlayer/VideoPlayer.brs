function init()
    m.top.focusable = true
    m.top.observeField("visible", "onVisibleChange")

    m.video = m.top.findNode("video")
    m.video.enableUI = false

    m.osd = m.top.findNode("osd")
    m.osdTimer = m.top.findNode("osdTimer")
    m.osdTimer.observeField("fire", "onOsdTimerFire")
    m.bufferingOverlay = m.top.findNode("bufferingOverlay")
    m.bufferingScrim = m.top.findNode("bufferingScrim")
    m.bufferingIndicator = m.top.findNode("bufferingIndicator")

    m.title = m.top.findNode("playerTitle")
    m.trackSummary = m.top.findNode("trackSummary")
    m.positionLabel = m.top.findNode("playerPosition")
    m.positionPauseIcon = m.top.findNode("playerPositionPauseIcon")
    m.durationLabel = m.top.findNode("playerDuration")
    m.progressTrack = m.top.findNode("playerProgressTrack")
    m.progressFill = m.top.findNode("playerProgressFill")
    m.progressThumb = m.top.findNode("playerProgressThumb")
    m.progressFocusTop = m.top.findNode("playerProgressFocusTop")
    m.progressFocusBottom = m.top.findNode("playerProgressFocusBottom")
    m.progressTrackWidth = 1728
    m.controlsGroup = m.top.findNode("controls")
    m.playbackSpeedSupported = isPlaybackSpeedSupported(m.video)

    m.trackMenu = m.top.findNode("trackMenu")
    m.trackMenuSelectionGuard = m.top.findNode("trackMenuSelectionGuard")
    m.trackMenuSelectionGuard.observeField("fire", "onTrackMenuSelectionGuardFire")
    m.startWatchdog = m.top.findNode("startWatchdog")
    m.startWatchdog.duration = getOriginalStartTimeoutSeconds()
    m.startWatchdog.observeField("fire", "onStartWatchdogFire")

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
            iconUri: "pkg:/images/icons/skip-back.png",
            focusedIconUri: "pkg:/images/icons/skip-back.png"
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
            iconUri: "pkg:/images/icons/play.png",
            focusedIconUri: "pkg:/images/icons/play.png"
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
            iconUri: "pkg:/images/icons/skip-forward.png",
            focusedIconUri: "pkg:/images/icons/skip-forward.png"
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
            showFocusBackground: true,
            iconUri: "pkg:/images/icons/audio-on.png",
            focusedIconUri: "pkg:/images/icons/audio-on.png"
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
            showFocusBackground: true,
            iconUri: "pkg:/images/icons/captions-off.png",
            focusedIconUri: "pkg:/images/icons/captions-off.png"
        },
        {
            node: m.top.findNode("speedButton"),
            background: m.top.findNode("speedBackground"),
            focusBar: m.top.findNode("speedFocus"),
            icon: m.top.findNode("speedIcon"),
            valueLabel: invalid,
            label: invalid,
            focusLabel: m.top.findNode("speedFocusLabel"),
            width: 88,
            action: "speed",
            showFocusBackground: true,
            iconUri: "pkg:/images/icons/speed.png",
            focusedIconUri: "pkg:/images/icons/speed.png"
        }
    ]
    applyPlayerColors()

    m.focusIndex = 1
    m.focusArea = "progress"
    m.progressReturnFocusIndex = 1
    m.duration = 0
    m.pendingSeekPosition = invalid
    m.seekInProgress = false
    m.seekValue = 0
    m.seekPressCount = 0
    m.seekDirection = 0
    m.seekRepeatWindowMs = 500
    m.seekPressTimer = CreateObject("roTimespan")
    m.wasPlayingBeforeSeek = false
    m.playbackSpeedCheckWindowMs = 8000
    m.playbackSpeedCheckMaxGapMs = 2000
    m.resumeSaveIntervalMs = 10000
    m.positionWriteTimeoutMs = 15000
    m.resumeSaveTimer = CreateObject("roTimespan")
    m.lastSavedVideoTime = invalid
    m.startFromClearState = "none"
    m.positionWriteTask = invalid
    m.queuedPositionWrite = invalid
    m.audioTracks = []
    m.rokuSubtitleTracks = []
    m.externalSubtitleTracks = []
    m.usesManifestSubtitles = false
    m.subtitleTracks = []
    m.trackMenuItems = []
    m.trackMenuMode = ""
    m.trackMenuFocusIndex = 0
    m.trackMenuReturnFocusIndex = 1
    m.selectedAudioTrack = invalid
    m.userSelectedAudioTrack = false
    m.selectedSubtitleTrackName = ""
    m.playbackSpeedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 3.5, 4.0]
    m.selectedPlaybackSpeed = 1.0
    m.selectedPlaybackSpeedLabel = "1x"
    m.playbackSpeedCheck = invalid
    m.canSelectTrackMenu = false
    m.hasPlaybackError = false
    m.errorDialog = invalid
    m.errorDialogShown = false
    m.currentStreamInfo = invalid
    m.playbackStarted = false
    m.playbackFile = invalid
    m.method = getDefaultPlaybackMethod()
    m.plan = invalid
    m.rescued = false
    m.reresolved = false
    m.reresolvedAtPosition = invalid
    m.playStartPosition = 0
    m.retryPosition = 0
    m.loadErrorSignature = ""
    m.startBufferingPercent = 0
    m.startWatchdogRearms = 0
    m.refetchFileTask = invalid
    m.failureReason = invalid
    m.errorDialogActions = []
    m.errorDialogAction = "back"
end function

function getOriginalStartTimeoutSeconds() as integer
    return 30
end function

function getStartWatchdogMaxRearms() as integer
    return 3
end function

sub applyPlayerColors()
    setDialogNodeColor(m.top.findNode("topShade"), "transparent")
    setDialogNodeColor(m.top.findNode("bottomShade"), "scrim")
    setDialogNodeColor(m.title, "text")
    setDialogNodeColor(m.trackSummary, "textMuted")
    setDialogNodeColor(m.positionLabel, "textMuted")
    setDialogNodeColor(m.progressFocusTop, "transparent")
    setDialogNodeColor(m.progressTrack, "border")
    setDialogNodeColor(m.progressFill, "primary")
    setDialogNodeColor(m.progressFocusBottom, "transparent")
    setDialogNodeColor(m.durationLabel, "textMuted")
    setDialogNodeColor(m.bufferingScrim, "scrim")
    applyTypography(m.title, "h1")
    applyTypography(m.trackSummary, "body")
    applyTypography(m.positionLabel, "small")
    applyTypography(m.durationLabel, "small")

    for each control in m.controls
        setDialogNodeColor(control.focusBar, "transparent")
        setDialogNodeColor(control.label, "text")
        setDialogNodeColor(control.focusLabel, "textMuted")
        applyTypography(control.label, "label")
        applyTypography(control.focusLabel, "small")
    end for
end sub

function isPlaybackSpeedSupported(video) as boolean
    if video = invalid or video.hasField("playbackSpeed") = false
        return false
    end if

    deviceInfo = CreateObject("roDeviceInfo")
    model = deviceInfo.GetModel()

    ' The 3500X exposes Video.playbackSpeed but keeps advancing at 1.0x on HLS.
    if model = "3500X"
        return false
    end if

    return true
end function

sub onVisibleChange()
    if m.top.visible
        m.video.notificationInterval = 1
        m.video.observeField("state", "onPlayerStateChanged")
        m.video.observeField("position", "onPlayerPositionChanged")
        m.video.observeField("duration", "onPlayerDurationChanged")
        m.video.observeField("availableAudioTracks", "onAvailableAudioTracksChanged")
        m.video.observeField("availableSubtitleTracks", "onAvailableSubtitleTracksChanged")
        if m.video.hasField("audioTrack")
            m.video.observeField("audioTrack", "onAudioTrackChanged")
        end if
        if m.video.hasField("currentAudioTrack")
            m.video.observeField("currentAudioTrack", "onAudioTrackChanged")
        end if

        setupPlayer()
        showOsd()
    else
        m.video.control = "stop"
        updateBufferingOverlay(false)
        m.video.unobserveField("state")
        m.video.unobserveField("position")
        m.video.unobserveField("duration")
        m.video.unobserveField("availableAudioTracks")
        m.video.unobserveField("availableSubtitleTracks")
        if m.video.hasField("audioTrack")
            m.video.unobserveField("audioTrack")
        end if
        if m.video.hasField("currentAudioTrack")
            m.video.unobserveField("currentAudioTrack")
        end if
        m.osdTimer.control = "stop"
        m.trackMenuSelectionGuard.control = "stop"
        m.startWatchdog.control = "stop"
        cancelRefetchFile()
        m.trackMenu.visible = false
    end if
end sub

sub setupPlayer()
    file = m.top.params.file

    resetPlaybackState()

    m.playbackFile = file
    m.method = normalizePlaybackMethod(m.top.params.method)
    m.plan = m.top.params.plan
    m.title.text = file.name
    m.duration = getVideoFileDurationSeconds(file)
    updateDurationLabel()

    startFrom = m.top.params.startFrom
    if startFrom = invalid
        startFrom = 0
    end if

    if m.plan = invalid or m.plan.action <> "play" or isNonEmptyString(m.plan.url) = false
        reason = "not_ready"
        if m.plan <> invalid and isNonEmptyString(m.plan.reason)
            reason = m.plan.reason
        end if
        m.retryPosition = startFrom
        showPlaybackFailureDialog(reason, true)
        return
    end if

    m.externalSubtitleTracks = createSubtitleTracks(m.top.params.subtitles)
    m.usesManifestSubtitles = m.plan.streamFormat = "hls"
    syncSubtitleTracks()
    ensureDefaultSubtitleSelection()
    updateTrackSummary()

    loadPlaybackPlan(m.plan, startFrom)
end sub

sub loadPlaybackPlan(plan as object, startFrom)
    if startFrom = invalid
        startFrom = 0
    end if

    m.plan = plan
    m.usesManifestSubtitles = plan.streamFormat = "hls"
    syncSubtitleTracks()
    m.currentStreamInfo = { url: plan.url, format: plan.streamFormat }
    m.playStartPosition = startFrom
    m.hasPlaybackError = false
    m.errorDialogShown = false
    m.loadErrorSignature = getVideoErrorSignature()
    m.startBufferingPercent = 0
    m.startWatchdogRearms = 0
    resetPreviewSeek()
    m.pendingSeekPosition = invalid
    m.seekValue = 0
    m.userPaused = false

    videoContent = createObject("RoSGNode", "ContentNode")
    videoContent.url = plan.url
    videoContent.title = m.playbackFile.name
    videoContent.streamFormat = plan.streamFormat
    if m.usesManifestSubtitles = false and m.externalSubtitleTracks.count() > 0
        videoContent.SubtitleTracks = m.externalSubtitleTracks
    end if

    m.video.content = videoContent
    applySubtitleSelection()
    startPlayback(startFrom)

    m.startWatchdog.control = "stop"
    if plan.source = "original" and m.rescued = false and m.playbackStarted = false
        m.startWatchdog.control = "start"
    end if
end sub

function createPlaybackResolveContext(originalFailed as boolean, failureReason as dynamic) as object
    return {
        apiUrl: m.global.apiURL,
        downloadToken: m.global.user.download_token,
        probe: createRokuDecoderProbe(),
        originalFailed: originalFailed,
        failureReason: failureReason
    }
end function

sub resetPlaybackState()
    if m.playbackSpeedSupported
        m.video.playbackSpeed = 1.0
    end if

    m.focusIndex = 1
    m.focusArea = "progress"
    m.progressReturnFocusIndex = 1
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
    m.trackMenuReturnFocusIndex = 1
    m.selectedAudioTrack = invalid
    m.userSelectedAudioTrack = false
    m.selectedSubtitleTrackName = invalid
    m.selectedPlaybackSpeed = 1.0
    m.selectedPlaybackSpeedLabel = "1x"
    m.playbackSpeedCheck = invalid
    m.canSelectTrackMenu = false
    m.hasPlaybackError = false
    m.errorDialog = invalid
    m.errorDialogShown = false
    m.currentStreamInfo = invalid
    m.playbackStarted = false
    m.rescued = false
    m.reresolved = false
    m.reresolvedAtPosition = invalid
    m.playStartPosition = 0
    m.retryPosition = 0
    m.loadErrorSignature = ""
    m.startBufferingPercent = 0
    m.startWatchdogRearms = 0
    m.failureReason = invalid
    m.errorDialogActions = []
    m.errorDialogAction = "back"
    m.startWatchdog.control = "stop"
    cancelRefetchFile()
    m.lastSavedVideoTime = invalid
    m.startFromClearState = "none"
    m.positionWriteTask = invalid
    m.queuedPositionWrite = invalid
    m.resumeSaveTimer = CreateObject("roTimespan")
    resetSeekPressTimer()

    m.trackMenu.visible = false
    updateBufferingOverlay(false)
    m.trackMenuSelectionGuard.control = "stop"
    m.positionLabel.text = getDurationString(0)
    updateProgress(0)
    updateTrackSummary()
end sub

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

    if state <> "playing"
        restartPlaybackSpeedCheckWindow()
    end if

    if state = "playing" or state = "buffering"
        enforcePlaybackSpeed()
    end if

    if state = "playing"
        m.playbackStarted = true
        m.userPaused = false
        m.startWatchdog.control = "stop"
    end if

    updatePlayIcon()
    updatePositionPauseIcon()

    if state = "error"
        handlePlaybackError(true)
    else if state = "finished"
        updateBufferingOverlay(false)
        if hasFreshVideoError()
            handlePlaybackError(true)
        else if m.hasPlaybackError = false
            if isPlaybackFinishedNormally()
                maybeSaveVideoTime(m.duration, true)
                onGoBack()
            else
                handlePlaybackError(false)
            end if
        end if
    else if state = "buffering"
        updateBufferingOverlay(m.userPaused <> true)
        showOsd()
    else
        updateBufferingOverlay(false)
        restartOsdTimer()
    end if
end sub

sub updateBufferingOverlay(visible as boolean)
    if m.bufferingOverlay = invalid
        return
    end if

    m.bufferingOverlay.visible = visible

    if m.bufferingIndicator = invalid
        return
    end if

    if visible
        m.bufferingIndicator.control = "start"
    else
        m.bufferingIndicator.control = "stop"
    end if
end sub

sub onPlayerPositionChanged(obj)
    position = obj.getData()
    checkPlaybackSpeed(position)

    if m.seekInProgress
        maybeSaveVideoTime(position, false)
        return
    end if

    ' A pause while the Video node re-buffers after a seek reports position 0.
    if m.userPaused = true and m.video.state <> "playing"
        return
    end if

    if position <> invalid
        displayedPosition = position

        if m.pendingSeekPosition <> invalid
            if Abs(position - m.pendingSeekPosition) <= 2
                displayedPosition = m.pendingSeekPosition
                m.pendingSeekPosition = invalid
            else
                return
            end if
        end if

        m.positionLabel.text = getDurationString(displayedPosition)
        updateProgress(displayedPosition)
    else
        m.positionLabel.text = "..:.."
    end if

    maybeSaveVideoTime(position, false)
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
    updatePositionPauseIcon()
end sub

sub updatePositionPauseIcon()
    if m.positionPauseIcon = invalid
        return
    end if

    showPausedGlyph = m.seekInProgress or isVideoPaused()
    m.positionPauseIcon.visible = showPausedGlyph

    if showPausedGlyph = false
        return
    end if

    m.positionPauseIcon.translation = [getPositionPauseIconX(), 56]
end sub

' The Video node keeps reporting "buffering" after control = "pause" while it waits for data, before the first frame and after a seek.
function isVideoPaused() as boolean
    return m.userPaused = true or m.video.state = "paused" or m.video.state = "pause"
end function

function getPositionPauseIconX() as integer
    positionText = m.positionLabel.text
    if positionText = invalid
        return 86
    end if

    textLength = Len(positionText)
    if textLength <= 5
        return 112
    else if textLength <= 8
        return 158
    end if

    return 188
end function

sub onAvailableAudioTracksChanged(obj)
    tracks = obj.getData()
    if tracks <> invalid
        m.audioTracks = tracks
    else
        m.audioTracks = []
    end if

    if m.userSelectedAudioTrack
        syncSelectedAudioTrackFromPlayer()
    else
        selectDefaultAudioTrack()
    end if

    updateTrackSummary()
end sub

sub onAudioTrackChanged(obj)
    if m.userSelectedAudioTrack = false
        return
    end if

    changedAudioTrack = obj.getData()
    if changedAudioTrack <> invalid and changedAudioTrack.toStr() <> "" and hasAudioTrack(changedAudioTrack)
        m.selectedAudioTrack = changedAudioTrack
        updateTrackSummary()
        return
    end if

    syncSelectedAudioTrackFromPlayer()
    updateTrackSummary()
end sub

sub selectDefaultAudioTrack()
    if m.audioTracks = invalid or m.audioTracks.count() = 0
        m.selectedAudioTrack = invalid
        return
    end if

    defaultAudioTrack = readTrackValue(m.audioTracks[getDefaultAudioTrackIndex()], "Track")
    if defaultAudioTrack = invalid
        return
    end if

    m.selectedAudioTrack = defaultAudioTrack
    if m.video.hasField("audioTrack")
        m.video.audioTrack = defaultAudioTrack.toStr()
    end if
end sub

' Roku lists an original's audio tracks in file order but picks one by the device language, not
' the default flag; put.io HLS manifests list the default first.
function getDefaultAudioTrackIndex() as integer
    if getCurrentPlaybackSource() <> "original" or m.playbackFile = invalid or m.playbackFile.media_info = invalid
        return 0
    end if

    streams = m.playbackFile.media_info.streams
    if getDirectPlayAudioStreams(streams).count() <> m.audioTracks.count()
        return 0
    end if

    return getDefaultAudioStreamIndex(streams)
end function

sub syncSelectedAudioTrackFromPlayer()
    if m.audioTracks = invalid or m.audioTracks.count() = 0
        m.selectedAudioTrack = invalid
        return
    end if

    currentAudioTrack = getCurrentAudioTrack()
    if currentAudioTrack <> invalid and hasAudioTrack(currentAudioTrack)
        m.selectedAudioTrack = currentAudioTrack
        return
    end if

    if m.selectedAudioTrack <> invalid and hasAudioTrack(m.selectedAudioTrack)
        return
    end if

    m.selectedAudioTrack = readTrackValue(m.audioTracks[0], "Track")
end sub

function getCurrentAudioTrack()
    if m.video.hasField("currentAudioTrack")
        currentAudioTrack = m.video.currentAudioTrack
        if currentAudioTrack <> invalid and currentAudioTrack.toStr() <> ""
            return currentAudioTrack
        end if
    end if

    if m.video.hasField("audioTrack")
        audioTrack = m.video.audioTrack
        if audioTrack <> invalid and audioTrack.toStr() <> ""
            return audioTrack
        end if
    end if

    return invalid
end function

function hasAudioTrack(trackValue) as boolean
    if trackValue = invalid
        return false
    end if

    for each track in m.audioTracks
        audioTrack = readTrackValue(track, "Track")
        if audioTrack <> invalid and audioTrack.toStr() = trackValue.toStr()
            return true
        end if
    end for

    return false
end function

sub onAvailableSubtitleTracksChanged(obj)
    tracks = obj.getData()
    if tracks <> invalid
        m.rokuSubtitleTracks = tracks
    else
        m.rokuSubtitleTracks = []
    end if

    syncSubtitleTracks()
    if m.selectedSubtitleTrackName <> invalid and m.selectedSubtitleTrackName <> ""
        m.selectedSubtitleTrackName = getAvailableSubtitleTrackName(m.selectedSubtitleTrackName)
    end if
    ensureDefaultSubtitleSelection()
    applySubtitleSelection()
    updateTrackSummary()
end sub

sub syncSubtitleTracks()
    m.subtitleTracks = []

    if m.usesManifestSubtitles = true
        addManifestSubtitleTracks()
        dropUnavailableSubtitleSelection()
        return
    end if

    if m.externalSubtitleTracks <> invalid
        for each track in m.externalSubtitleTracks
            addUniqueSubtitleTrack(createSelectableSubtitleTrack(track))
        end for
    end if

    addUniqueSubtitleTracks(m.rokuSubtitleTracks)
end sub

function createSelectableSubtitleTrack(track)
    trackName = readTrackValue(track, "TrackName")
    return {
        Language: readTrackValue(track, "Language"),
        Name: readTrackValue(track, "Name"),
        TrackName: getAvailableSubtitleTrackName(trackName),
        Description: readTrackValue(track, "Description")
    }
end function

sub addManifestSubtitleTracks()
    manifestTracks = []
    for each track in m.rokuSubtitleTracks
        if isExternalSubtitleTrackName(readTrackValue(track, "TrackName")) = false
            manifestTracks.push(track)
        end if
    end for

    matches = matchManifestSubtitles(manifestTracks, m.top.params.subtitles)
    for i = 0 to manifestTracks.count() - 1
        track = manifestTracks[i]
        name = readTrackValue(track, "Description")
        if matches[i] <> invalid
            name = getSubtitleLabel(matches[i])
        end if
        addUniqueSubtitleTrack({
            Language: readTrackValue(track, "Language"),
            Name: name,
            TrackName: readTrackValue(track, "TrackName"),
            Description: readTrackValue(track, "Description")
        })
    end for
end sub

sub dropUnavailableSubtitleSelection()
    if m.selectedSubtitleTrackName <> invalid and m.selectedSubtitleTrackName <> "" and hasSubtitleTrack(m.selectedSubtitleTrackName) = false
        m.selectedSubtitleTrackName = invalid
    end if
end sub

sub ensureDefaultSubtitleSelection()
    if m.selectedSubtitleTrackName <> invalid
        return
    end if

    if m.subtitleTracks = invalid or m.subtitleTracks.count() = 0
        return
    end if

    trackName = readTrackValue(m.subtitleTracks[0], "TrackName")
    if trackName <> invalid and trackName <> ""
        m.selectedSubtitleTrackName = trackName.toStr()
    end if
end sub

sub addUniqueSubtitleTracks(tracks)
    if tracks = invalid
        return
    end if

    for each track in tracks
        addUniqueSubtitleTrack(track)
    end for
end sub

sub addUniqueSubtitleTrack(track)
    if track = invalid
        return
    end if

    trackName = readTrackValue(track, "TrackName")
    if trackName = invalid or trackName = "" or hasSubtitleTrack(trackName) = false
        m.subtitleTracks.push(track)
    end if
end sub

function hasSubtitleTrack(trackName) as boolean
    if trackName = invalid or trackName = ""
        return false
    end if

    for each track in m.subtitleTracks
        existingTrackName = readTrackValue(track, "TrackName")
        if subtitleTrackNamesMatch(existingTrackName, trackName)
            return true
        end if
    end for

    return false
end function

function isExternalSubtitleTrackName(trackName) as boolean
    if m.externalSubtitleTracks = invalid
        return false
    end if

    for each track in m.externalSubtitleTracks
        if subtitleTrackNamesMatch(readTrackValue(track, "TrackName"), trackName)
            return true
        end if
    end for

    return false
end function

function getAvailableSubtitleTrackName(trackName)
    if trackName = invalid or trackName = ""
        return trackName
    end if

    if m.rokuSubtitleTracks = invalid
        return trackName
    end if

    for each track in m.rokuSubtitleTracks
        availableTrackName = readTrackValue(track, "TrackName")
        if subtitleTrackNamesMatch(availableTrackName, trackName)
            return availableTrackName
        end if
    end for

    return trackName
end function

function subtitleTrackNamesMatch(leftTrackName, rightTrackName) as boolean
    if leftTrackName = invalid or rightTrackName = invalid
        return false
    end if

    leftValue = leftTrackName.toStr()
    rightValue = rightTrackName.toStr()

    if leftValue = "" or rightValue = ""
        return false
    end if

    return leftValue = rightValue or Right(leftValue, Len(rightValue)) = rightValue or Right(rightValue, Len(leftValue)) = leftValue
end function

sub updateTrackSummary()
    m.trackSummary.text = ""
    updateTrackControlIcons()
    updateTrackControlVisibility()
end sub

sub updateTrackControlIcons()
    if m.selectedAudioTrack <> invalid
        m.controls[3].iconUri = "pkg:/images/icons/audio-on.png"
        m.controls[3].focusedIconUri = "pkg:/images/icons/audio-on.png"
    else
        m.controls[3].iconUri = "pkg:/images/icons/audio-off.png"
        m.controls[3].focusedIconUri = "pkg:/images/icons/audio-off.png"
    end if

    if m.selectedSubtitleTrackName <> invalid and m.selectedSubtitleTrackName <> ""
        m.controls[4].iconUri = "pkg:/images/icons/captions-on.png"
        m.controls[4].focusedIconUri = "pkg:/images/icons/captions-on.png"
    else
        m.controls[4].iconUri = "pkg:/images/icons/captions-off.png"
        m.controls[4].focusedIconUri = "pkg:/images/icons/captions-off.png"
    end if
end sub

sub updateTrackControlVisibility()
    hasAudioChoices = m.video.hasField("audioTrack") and m.audioTracks <> invalid and m.audioTracks.count() > 1
    hasCaptionChoices = m.subtitleTracks <> invalid and m.subtitleTracks.count() > 0

    m.controls[0].node.visible = false
    m.controls[1].node.visible = false
    m.controls[2].node.visible = false
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

    m.controlsGroup.translation = [0, 870]
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
                control.valueLabel.color = dialogColor("primary")
            else
                control.valueLabel.color = dialogColor("textMuted")
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
        m.progressTrack.translation = [0, 23]
        m.progressTrack.height = 12
        m.progressTrack.color = dialogColor("panelBorder")
        m.progressFill.translation = [0, 23]
        m.progressFill.height = 12
        m.progressFill.color = dialogColor("primary")
        m.progressFocusTop.width = 0
        m.progressFocusTop.height = 0
        m.progressFocusBottom.width = 0
        m.progressFocusBottom.height = 0
        m.progressThumb.uri = "pkg:/images/player-progress-thumb-focused.png"
        m.progressThumb.width = 34
        m.progressThumb.height = 34
        m.progressThumb.visible = true
    else
        m.progressTrack.translation = [0, 25]
        m.progressTrack.height = 8
        m.progressTrack.color = dialogColor("border")
        m.progressFill.translation = [0, 25]
        m.progressFill.height = 8
        m.progressFill.color = dialogColor("primary")
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

    firstAvailableIndex = getFirstAvailableControlIndex()
    if firstAvailableIndex <> invalid
        m.focusIndex = firstAvailableIndex
        return
    end if
end sub

function getFirstAvailableControlIndex()
    for i = 0 to m.controls.count() - 1
        if isControlAvailable(i)
            return i
        end if
    end for

    return invalid
end function

sub updatePlayIcon()
    if m.userPaused <> true and (m.video.state = "playing" or m.video.state = "buffering")
        m.controls[1].icon.uri = "pkg:/images/icons/pause.png"
    else
        m.controls[1].icon.uri = "pkg:/images/icons/play.png"
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
    firstAvailableIndex = getFirstAvailableControlIndex()
    if firstAvailableIndex = invalid
        focusProgress()
        return
    end if

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

    if isVideoPaused()
        resumePlayback()
    else
        pausePlayback()
    end if

    showOsd()
end sub

sub pausePlayback()
    m.userPaused = true
    m.startWatchdog.control = "stop"
    m.video.control = "pause"
    updateBufferingOverlay(false)
    updatePlayIcon()
    updatePositionPauseIcon()
end sub

sub resumePlayback()
    m.userPaused = false
    m.video.control = "resume"
    m.startBufferingPercent = 0
    m.startWatchdogRearms = 0
    if m.playbackStarted = false and m.plan <> invalid and m.plan.source = "original" and m.rescued = false and m.hasPlaybackError = false
        m.startWatchdog.control = "start"
    end if
    if m.video.state = "buffering"
        updateBufferingOverlay(true)
    end if
    updatePlayIcon()
    updatePositionPauseIcon()
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
    shouldResume = false

    if m.seekInProgress
        shouldResume = m.wasPlayingBeforeSeek
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
    maybeSaveVideoTime(nextPosition, true)

    if shouldResume
        resumePlayback()
    end if

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
        restartPlaybackSpeedCheckWindow()
        m.wasPlayingBeforeSeek = isVideoPaused() = false and (m.video.state = "playing" or m.video.state = "buffering")
        m.seekPressCount = 0
        m.seekDirection = direction
        resetSeekPressTimer()

        if m.wasPlayingBeforeSeek
            m.startWatchdog.control = "stop"
            m.video.control = "pause"
        end if
    else if direction <> m.seekDirection
        m.seekPressCount = 0
        m.seekDirection = direction
        resetSeekPressTimer()
    end if
end sub

function getSeekDirection(seconds) as integer
    if seconds < 0
        return -1
    end if

    return 1
end function

function getPreviewSeekDelta(seconds) as integer
    if m.seekPressTimer <> invalid and m.seekPressTimer.TotalMilliseconds() > m.seekRepeatWindowMs
        m.seekPressCount = 0
    end if

    m.seekPressCount = m.seekPressCount + 1
    resetSeekPressTimer()

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
    shouldResume = m.wasPlayingBeforeSeek
    resetPreviewSeek()
    m.pendingSeekPosition = seekPosition
    m.positionLabel.text = getDurationString(seekPosition)
    updateProgress(seekPosition)
    m.video.seek = seekPosition
    maybeSaveVideoTime(seekPosition, true)

    if shouldResume
        resumePlayback()
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
        resumePlayback()
    end if

    showOsd()
end sub

sub resetPreviewSeek()
    m.seekInProgress = false
    m.seekPressCount = 0
    m.seekDirection = 0
    m.wasPlayingBeforeSeek = false
    resetSeekPressTimer()
end sub

sub resetSeekPressTimer()
    m.seekPressTimer = CreateObject("roTimespan")
end sub

sub seekToStart()
    resetPreviewSeek()
    m.pendingSeekPosition = 0
    m.positionLabel.text = getDurationString(0)
    updateProgress(0)
    m.video.seek = 0
    showOsd()
end sub

' Roku does not document clearing errorCode, errorInfo or errorStr when content changes, so after
' a rescue or re-resolve they are read only for an error state or a finished state with a new error.
sub handlePlaybackError(useErrorFields as boolean)
    if m.hasPlaybackError
        return
    end if

    m.hasPlaybackError = true
    m.startWatchdog.control = "stop"
    updateBufferingOverlay(false)
    m.osdTimer.control = "stop"

    errorVideo = invalid
    rawErrorCode = 0
    errorStr = invalid
    if useErrorFields
        errorVideo = m.video
        rawErrorCode = m.video.errorCode
        errorStr = getVideoErrorStr()
    end if

    position = getRecoveryPosition()
    errorInfo = sentryVideoErrorInfo(errorVideo)
    verdict = classifyPlaybackFailure({
        errorCode: rawErrorCode,
        errorInfo: errorInfo,
        errorStr: errorStr,
        started: m.playbackStarted,
        source: getCurrentPlaybackSource(),
        rescued: m.rescued,
        reresolved: isReresolveBudgetSpent()
    })
    errorCode = sentryVideoErrorCode(errorVideo)
    m.reresolveFailureEvent = invalid
    if verdict.action = "retry" or verdict.action = "fail"
        reportPlaybackFailure(errorVideo)
    else if verdict.action = "reresolve"
        m.reresolveFailureEvent = createPlaybackFailureEventFor(errorVideo)
    end if
    m.video.control = "stop"

    if verdict.action = "rescue"
        rescuePlayback(verdict.reason, "engine", errorCode, errorInfo)
    else if verdict.action = "reresolve"
        reresolvePlayback(position)
    else
        m.retryPosition = position
        showPlaybackFailureDialog(verdict.reason, false)
    end if
end sub

sub onStartWatchdogFire()
    if m.playbackStarted or m.hasPlaybackError or m.plan = invalid or m.plan.source <> "original" or m.rescued
        return
    end if

    if m.userPaused = true
        return
    end if

    if hasStartBufferingProgress()
        m.startWatchdog.control = "start"
        return
    end if

    m.hasPlaybackError = true
    updateBufferingOverlay(false)
    m.video.control = "stop"
    rescuePlayback("decoder_error", "watchdog", invalid, invalid)
end sub

' A 4K or high-bitrate original, or an MKV resume seek without front Cues, can still be filling
' its buffer at the timeout; keep waiting while bufferingStatus.percentage grows.
function hasStartBufferingProgress() as boolean
    if m.startWatchdogRearms >= getStartWatchdogMaxRearms()
        return false
    end if

    status = m.video.bufferingStatus
    if type(status) <> "roAssociativeArray" or status.percentage = invalid
        return false
    end if

    percentage = Int(status.percentage)
    if percentage <= m.startBufferingPercent
        return false
    end if

    m.startBufferingPercent = percentage
    m.startWatchdogRearms = m.startWatchdogRearms + 1
    return true
end function

function getRecoveryPosition()
    if m.playbackStarted and m.video.position <> invalid and m.video.position > 0
        return Int(m.video.position)
    end if

    return m.playStartPosition
end function

function getVideoErrorStr() as dynamic
    if m.video.hasField("errorStr")
        return m.video.errorStr
    end if

    return invalid
end function

sub rescuePlayback(reason as string, trigger as string, errorCode as dynamic, errorInfo as dynamic)
    m.rescued = true
    fromSource = m.plan.source
    plan = resolvePlaybackPlan(m.playbackFile, m.method, createPlaybackResolveContext(true, reason))
    sentryCaptureEvent(createPlaybackRescueEvent({
        reason: reason,
        trigger: trigger,
        method: m.method,
        fromSource: fromSource,
        plan: plan,
        file: m.playbackFile,
        errorCode: errorCode,
        errorInfo: errorInfo,
    }))

    if plan.action = "play"
        resetSourceTracks()
        loadPlaybackPlan(plan, m.playStartPosition)
    else if plan.action = "convert"
        openVideoScreen({ methodOverride: m.method, rescueReason: reason, startFrom: m.playStartPosition })
    else
        m.retryPosition = m.playStartPosition
        showPlaybackFailureDialog(plan.reason, true)
    end if
end sub

sub resetSourceTracks()
    m.audioTracks = []
    m.rokuSubtitleTracks = []
    if m.selectedSubtitleTrackName <> invalid and m.selectedSubtitleTrackName <> "" and isExternalSubtitleTrackName(m.selectedSubtitleTrackName) = false
        m.selectedSubtitleTrackName = invalid
    end if
    m.selectedAudioTrack = invalid
    m.userSelectedAudioTrack = false
    syncSubtitleTracks()
    updateTrackSummary()
end sub

function isReresolveBudgetSpent() as boolean
    if m.reresolved <> true
        return false
    end if

    if m.reresolvedAtPosition = invalid or m.video.position = invalid
        return true
    end if

    return m.video.position - m.reresolvedAtPosition < getReresolvePlaybackSeconds()
end function

function getReresolvePlaybackSeconds() as integer
    return 5
end function

sub reresolvePlayback(position)
    m.reresolved = true
    m.reresolvedAtPosition = position
    m.retryPosition = position
    cancelRefetchFile()
    hideOsd()
    updateBufferingOverlay(true)

    fileId = m.playbackFile.id.toStr()
    m.refetchFileTask = createObject("roSGNode", "HttpTask")
    m.refetchFileTask.observeField("response", "onRefetchFileResponse")
    m.refetchFileTask.url = "/files/list?parent_id=" + fileId + "&mp4_status_parent=1&stream_url_parent=1&mp4_stream_url_parent=1&video_metadata_parent=1&media_info_parent=1&codecs_parent=1"
    m.refetchFileTask.method = "GET"
    m.refetchFileTask.control = "RUN"
end sub

sub cancelRefetchFile()
    if m.refetchFileTask <> invalid
        m.refetchFileTask.unobserveField("response")
        m.refetchFileTask.control = "stop"
        m.refetchFileTask = invalid
    end if
end sub

sub onRefetchFileResponse(obj)
    cancelRefetchFile()
    data = parseJSON(obj.getData())

    plan = createUnplayablePlan("link_expired")
    if data <> invalid and data.parent <> invalid
        m.playbackFile = data.parent
        plan = resolveSameSourcePlaybackPlan(m.playbackFile, m.plan, createPlaybackResolveContext(false, invalid))
    end if

    failureEvent = m.reresolveFailureEvent
    m.reresolveFailureEvent = invalid
    if plan.action = "play"
        loadPlaybackPlan(plan, m.retryPosition)
    else
        if failureEvent <> invalid and m.errorDialogShown = false
            sentryCaptureEvent(failureEvent)
        end if
        updateBufferingOverlay(false)
        showPlaybackFailureDialog(plan.reason, false)
    end if
end sub

sub openVideoScreen(params as object)
    m.video.control = "stop"
    params.fileId = m.playbackFile.id
    params.fileName = m.playbackFile.name
    m.top.navigate = {
        id: "videoScreen",
        replace: true,
        params: params
    }
end sub

' Reads the Video node before control = "stop" clears errorInfo, then hands off to a task.
sub reportPlaybackFailure(errorVideo as dynamic)
    if m.errorDialogShown
        return
    end if

    sentryCaptureEvent(createPlaybackFailureEventFor(errorVideo))
end sub

function createPlaybackFailureEventFor(errorVideo as dynamic) as object
    return createPlaybackFailureEvent({
        video: errorVideo,
        file: m.playbackFile,
        streamInfo: m.currentStreamInfo,
        method: m.method,
        source: getCurrentPlaybackSource(),
        playbackStarted: m.playbackStarted,
    })
end function

function getCurrentPlaybackSource() as dynamic
    if m.plan <> invalid
        return m.plan.source
    end if

    return invalid
end function

function getVideoErrorSignature() as string
    if getSafeVideoErrorMessage() = "" and getSafeVideoErrorCode() = ""
        return ""
    end if

    return getSafeVideoErrorCode() + "|" + getSafeVideoErrorMessage()
end function

function hasFreshVideoError() as boolean
    signature = getVideoErrorSignature()
    return signature <> "" and signature <> m.loadErrorSignature
end function

function isPlaybackFinishedNormally() as boolean
    if m.duration <= 0
        return false
    end if

    return getDisplayedPosition() >= (m.duration - 2)
end function

sub showPlaybackFailureDialog(reason as string, unplayable as boolean)
    m.errorDialogShown = true
    m.failureReason = reason
    m.errorDialogActions = getPlaybackErrorDialogActions(reason, m.method)
    m.errorDialogAction = "back"

    m.errorDialog = createObject("roSGNode", "AppDialog")
    m.errorDialog.title = buildPlaybackErrorDialogTitle(reason)
    if unplayable
        m.errorDialog.message = buildUnplayableDialogMessage(reason, m.method)
    else
        m.errorDialog.message = buildPlaybackErrorDialogMessage(reason, getCurrentPlaybackSource())
    end if
    applyAccountNoticeToDialog(m.errorDialog, m.global.user)
    m.errorDialog.buttons = getPlaybackErrorDialogButtons(m.errorDialogActions)
    m.errorDialog.observeField("buttonSelected", "onErrorDialogButtonSelected")
    m.errorDialog.observeField("wasClosed", "onErrorDialogClosed")
    m.top.showDialog = m.errorDialog
end sub

function getSafeVideoErrorMessage() as string
    if m.video <> invalid and m.video.errorMsg <> invalid and m.video.errorMsg.toStr() <> ""
        return m.video.errorMsg.toStr()
    end if

    return ""
end function

function getSafeVideoErrorCode() as string
    if m.video <> invalid and m.video.errorCode <> invalid and m.video.errorCode.toStr() <> "" and m.video.errorCode.toStr() <> "0"
        return m.video.errorCode.toStr()
    end if

    return ""
end function

sub onErrorDialogButtonSelected(obj)
    index = obj.getData()
    if index >= 0 and index < m.errorDialogActions.count()
        m.errorDialogAction = m.errorDialogActions[index]
    end if
end sub

sub onErrorDialogClosed()
    if m.errorDialog <> invalid
        m.errorDialog.unobserveField("buttonSelected")
        m.errorDialog.unobserveField("wasClosed")
        m.errorDialog = invalid
    end if

    action = m.errorDialogAction
    m.errorDialogAction = "back"

    if action = "retry"
        retryPlayback()
    else if action = "play_standard"
        openVideoScreen({ methodOverride: "hls", startFrom: m.retryPosition })
    else
        onGoBack()
    end if
end sub

sub retryPlayback()
    if m.failureReason = "link_expired"
        m.reresolved = false
        m.hasPlaybackError = false
        m.errorDialogShown = false
        reresolvePlayback(m.retryPosition)
    else if m.plan <> invalid and m.plan.action = "play"
        loadPlaybackPlan(m.plan, m.retryPosition)
    else
        openVideoScreen({ methodOverride: m.method, startFrom: m.retryPosition })
    end if
end sub

sub maybeSaveVideoTime(time, force as boolean)
    if m.global.user.settings.start_from <> true or time = invalid or time <= 0
        return
    end if

    if isPlaybackFinishedAt(time, m.duration)
        if force or m.resumeSaveTimer = invalid or m.resumeSaveTimer.TotalMilliseconds() >= m.resumeSaveIntervalMs
            clearVideoTime()
        end if
        return
    end if

    if force = false and m.resumeSaveTimer <> invalid and m.resumeSaveTimer.TotalMilliseconds() < m.resumeSaveIntervalMs
        return
    end if

    if m.lastSavedVideoTime <> invalid and Abs(time - m.lastSavedVideoTime) < 1
        return
    end if

    saveVideoTime(time)
end sub

sub saveVideoTime(time)
    if time = invalid or time <= 0
        return
    end if

    m.lastSavedVideoTime = time
    m.startFromClearState = "none"
    m.resumeSaveTimer = CreateObject("roTimespan")
    requestPositionWrite({ kind: "set", time: time })
end sub

sub clearVideoTime()
    if m.startFromClearState <> "none"
        return
    end if

    m.startFromClearState = "pending"
    m.lastSavedVideoTime = invalid
    requestPositionWrite({ kind: "clear" })
end sub

' put.io applies start-from writes in arrival order, so only one runs at a time and the latest queued write wins.
sub requestPositionWrite(write as object)
    if m.positionWriteTask <> invalid and m.positionWriteTimer.TotalMilliseconds() < m.positionWriteTimeoutMs
        m.queuedPositionWrite = write
        return
    end if

    m.queuedPositionWrite = invalid
    sendPositionWrite(write)
end sub

sub sendPositionWrite(write as object)
    fileUrl = "/files/" + m.top.params.file.id.toStr()
    task = createObject("roSGNode", "HttpTask")
    task.method = "POST"
    if write.kind = "clear"
        task.url = fileUrl + "/start-from/delete"
    else
        task.url = fileUrl + "/start-from/set"
        task.body = { time: write.time }
    end if
    task.observeField("response", "onPositionWriteResponse")
    m.positionWriteTask = task
    m.positionWriteKind = write.kind
    m.positionWriteTimer = CreateObject("roTimespan")
    task.control = "RUN"
end sub

sub onPositionWriteResponse(obj)
    task = obj.getRoSGNode()
    task.unobserveField("response")
    if m.positionWriteTask = invalid or not task.isSameNode(m.positionWriteTask)
        return
    end if

    m.positionWriteTask = invalid
    if m.positionWriteKind = "clear" and m.startFromClearState = "pending"
        data = parseJSON(obj.getData())
        if data <> invalid and data.status = "OK"
            m.startFromClearState = "done"
        else
            m.startFromClearState = "none"
            m.resumeSaveTimer = CreateObject("roTimespan")
        end if
    end if

    if m.queuedPositionWrite <> invalid
        write = m.queuedPositionWrite
        m.queuedPositionWrite = invalid
        sendPositionWrite(write)
    end if
end sub

sub onGoBack()
    m.startWatchdog.control = "stop"
    m.video.control = "stop"
    m.top.navigateBack = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.trackMenu.visible and press = false
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

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

        if m.hasPlaybackError or m.refetchFileTask <> invalid
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
                return true
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

            pausePlayback()
            showOsd()
            return true
        else if normalizedKey = "rewind" or normalizedKey = "rev"
            rewind()
            return true
        else if normalizedKey = "fastforward" or normalizedKey = "fwd"
            fastforward()
            return true
        else if normalizedKey = "replay" or normalizedKey = "instantreplay"
            rewind()
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
            else if m.focusArea = "progress"
                focusControls()
            else
                focusControls()
            end if
        else if normalizedKey = "down"
            showOsd()
            if osdWasHidden
                focusProgress()
            else if m.focusArea = "controls"
                focusProgress()
            else
                focusProgress()
            end if
        else if normalizedKey = "ok" or normalizedKey = "select"
            showOsd()
            if osdWasHidden
                focusProgress()
            else
                activateFocusedControl()
            end if
        else if isOptionsKey(normalizedKey)
            showOsd()
            if getFirstAvailableControlIndex() <> invalid
                focusControls()
            else if osdWasHidden
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
