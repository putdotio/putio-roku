function init()
    m.top.observeField("visible", "onVisibleChange")

    m.file = {}
    m.subtitles = []
    m.phase = "idle"
    m.fetchedStartFrom = 0
    m.method = getDefaultPlaybackMethod()
    m.plan = invalid
    m.conversionCompleted = false
    m.unavailableActions = []
    m.unavailableAction = "back"
    m.fetchFileTask = createObject("roSGNode", "HttpTask")
    m.fetchConfigTask = createObject("roSGNode", "HttpTask")
    m.fetchSubtitlesTask = createObject("roSGNode", "HttpTask")
    m.fetchStartFromTask = createObject("roSGNode", "HttpTask")
    m.continueWatchingPrompt = m.top.findNode("continueWatchingPrompt")
    m.continueWatchingPrompt.observeField("selectedStartFrom", "onContinueWatchingPromptSelected")
    m.continueWatchingPrompt.observeField("dismissed", "onContinueWatchingPromptDismissed")
    m.conversionStatus = m.top.findNode("conversionStatus")
    m.conversionStatus.observeField("completed", "onVideoConversionCompleted")
    m.conversionStatus.observeField("dismissed", "onVideoConversionDismissed")
    m.conversionStatus.observeField("failedStatus", "onVideoConversionFailed")
end function

sub onVisibleChange()
    if m.top.visible
        onMount()
    else
        cancelHttpTasks()
    end if
end sub

sub onMount()
    hideOverlays()
    setTitle(m.top.params.fileName)
    showLoading()
    m.conversionCompleted = false

    if m.file.id <> m.top.params.fileId
        m.file = {}
        m.subtitles = []
        fetchFile(m.top.params.fileId)
    else
        handleFetchedFile()
    end if
end sub

sub cancelHttpTasks()
    m.fetchFileTask.unobserveField("response")
    m.fetchConfigTask.unobserveField("response")
    m.fetchSubtitlesTask.unobserveField("response")
    m.fetchStartFromTask.unobserveField("response")
    m.conversionStatus.control = "stop"
end sub

sub fetchFile(fileId)
    m.phase = "loadingFile"
    m.fetchFileTask.observeField("response", "onFetchFileResponse")
    m.fetchFileTask.url = ("/files/list?parent_id=" + fileId.toStr() + "&mp4_status_parent=1&stream_url_parent=1&mp4_stream_url_parent=1&video_metadata_parent=1&media_info_parent=1&codecs_parent=1")
    m.fetchFileTask.method = "GET"
    m.fetchFileTask.control = "RUN"
end sub

sub onFetchFileResponse(obj)
    m.fetchFileTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.parent <> invalid
        m.file = data.parent
        setTitle(m.file.name)
        handleFetchedFile()
    else
        hideLoading()
        sentryCaptureEvent(createSourceRequestFailureEvent(m.top.params.fileId, data))
        showFetchFileErrorDialog(data)
    end if
end sub

sub handleFetchedFile()
    fetchPlaybackConfig()
end sub

sub fetchPlaybackConfig()
    m.phase = "loadingConfig"
    m.fetchConfigTask.observeField("response", "onFetchPlaybackConfigResponse")
    m.fetchConfigTask.url = "/config"
    m.fetchConfigTask.method = "GET"
    m.fetchConfigTask.control = "RUN"
end sub

sub onFetchPlaybackConfigResponse(obj)
    m.fetchConfigTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.config <> invalid
        config = m.global.config
        if config = invalid
            config = {}
        end if
        config.streaming_method = getPlaybackMethodFromConfig(data.config)
        m.global.config = config
    end if

    m.method = getRequestedPlaybackMethod()
    rescueReason = m.top.params.rescueReason
    resolvePlayback(isNonEmptyString(rescueReason), rescueReason)
end sub

function getRequestedPlaybackMethod() as string
    if m.top.params.methodOverride <> invalid
        return normalizePlaybackMethod(m.top.params.methodOverride)
    end if

    return getPlaybackMethodFromConfig(m.global.config)
end function

sub resolvePlayback(originalFailed as boolean, failureReason as dynamic)
    m.plan = resolvePlaybackPlan(m.file, m.method, {
        apiUrl: m.global.apiURL,
        downloadToken: m.global.user.download_token,
        probe: createRokuDecoderProbe(),
        originalFailed: originalFailed,
        failureReason: failureReason
    })

    if m.plan.action = "convert" and m.conversionCompleted
        m.plan = createUnplayablePlan("not_ready")
    end if

    if originalFailed = false and isPreflightRescue(m.plan)
        sentryCaptureEvent(createPlaybackRescueEvent({
            reason: m.plan.reason,
            trigger: "preflight",
            method: m.method,
            fromSource: "original",
            plan: m.plan,
            file: m.file,
        }))
    end if

    if m.plan.action = "convert"
        hideLoading()
        showVideoConversionStatus()
    else if m.plan.action = "unplayable"
        hideLoading()
        showPlaybackUnavailableDialog(m.plan.reason)
    else
        showLoading()
        fetchSubtitles()
    end if
end sub

function isPreflightRescue(plan as object) as boolean
    return m.method = "file" and plan.source <> "original" and isNonEmptyString(plan.reason)
end function

sub fetchSubtitles()
    m.phase = "loadingSubtitles"
    m.subtitles = []
    m.fetchSubtitlesTask.observeField("response", "onFetchSubtitlesResponse")
    m.fetchSubtitlesTask.url = ("/files/" + m.file.id.toStr() + "/subtitles")
    m.fetchSubtitlesTask.method = "GET"
    m.fetchSubtitlesTask.control = "RUN"
end sub

sub onFetchSubtitlesResponse(obj)
    m.fetchSubtitlesTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.subtitles <> invalid
        m.subtitles = data.subtitles
    end if

    if m.top.params.startFrom <> invalid
        hideLoading()
        navigateToVideoPlayer(m.top.params.startFrom)
        return
    end if

    fetchStartFrom()
end sub

sub fetchStartFrom()
    m.phase = "loadingStartFrom"
    m.fetchStartFromTask.observeField("response", "onFetchStartFromResponse")
    m.fetchStartFromTask.url = ("/files/" + m.file.id.toStr() + "/start-from")
    m.fetchStartFromTask.method = "GET"
    m.fetchStartFromTask.control = "RUN"
end sub

sub onFetchStartFromResponse(obj)
    m.fetchStartFromTask.unobserveField("response")
    data = parseJSON(obj.getData())
    hideLoading()

    if data <> invalid and data.start_from <> invalid and shouldResumeFrom(data.start_from)
        m.fetchedStartFrom = data.start_from
        if m.top.params.startFromChoice = "beginning"
            navigateToVideoPlayer(0)
        else if m.top.params.startFromChoice = "continue"
            navigateToVideoPlayer(m.fetchedStartFrom)
        else
            showContinueWatchingPrompt()
        end if
    else
        navigateToVideoPlayer(0)
    end if
end sub

sub setTitle(title)
    m.top.findNode("screenHeader").title = title
end sub

sub showLoading()
    m.top.findNode("loading").visible = "true"
end sub

sub hideLoading()
    m.top.findNode("loading").visible = "false"
end sub

sub hideOverlays()
    m.continueWatchingPrompt.visible = false
    m.conversionStatus.visible = false
    m.conversionStatus.control = "stop"
end sub

sub showFetchFileErrorDialog(data)
    m.fetchFileErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.fetchFileErrorDialog.error = data
    applyAccountNoticeToDialog(m.fetchFileErrorDialog, m.global.user)
    m.fetchFileErrorDialog.observeField("wasClosed", "onFetchFileErrorDialogClosed")
    m.top.showDialog = m.fetchFileErrorDialog
end sub

sub onFetchFileErrorDialogClosed()
    m.fetchFileErrorDialog.unobserveField("wasClosed")
    m.top.navigateBack = true
end sub

sub showPlaybackUnavailableDialog(reason as dynamic)
    m.phase = "unavailable"
    m.unavailableActions = getPlaybackErrorDialogActions(reason, m.method)
    m.unavailableAction = "back"
    m.playbackUnavailableDialog = createObject("roSGNode", "AppDialog")
    m.playbackUnavailableDialog.title = buildPlaybackErrorDialogTitle(reason)
    m.playbackUnavailableDialog.message = buildUnplayableDialogMessage(reason, m.method)
    m.playbackUnavailableDialog.buttons = getPlaybackErrorDialogButtons(m.unavailableActions)
    m.playbackUnavailableDialog.observeField("buttonSelected", "onPlaybackUnavailableDialogButtonSelected")
    m.playbackUnavailableDialog.observeField("wasClosed", "onPlaybackUnavailableDialogClosed")
    m.top.showDialog = m.playbackUnavailableDialog
end sub

sub onPlaybackUnavailableDialogButtonSelected(obj)
    index = obj.getData()
    if index >= 0 and index < m.unavailableActions.count()
        m.unavailableAction = m.unavailableActions[index]
    end if
end sub

sub onPlaybackUnavailableDialogClosed()
    m.playbackUnavailableDialog.unobserveField("buttonSelected")
    m.playbackUnavailableDialog.unobserveField("wasClosed")

    if m.unavailableAction = "play_standard"
        m.method = "hls"
        showLoading()
        resolvePlayback(false, invalid)
    else if m.unavailableAction = "retry"
        showVideoConversionStatus()
    else
        m.top.navigateBack = true
    end if
end sub

sub showVideoConversionStatus()
    m.phase = "conversion"
    m.conversionStatus.control = "stop"
    m.conversionStatus.fileName = m.file.name
    m.conversionStatus.fileId = m.file.id
    m.conversionStatus.visible = true
    m.conversionStatus.setFocus(true)
    m.conversionStatus.control = "start"
end sub

sub onVideoConversionDismissed()
    if m.phase = "conversion"
        m.conversionStatus.visible = false
        m.top.navigateBack = true
    end if
end sub

sub onVideoConversionFailed(obj)
    if m.phase <> "conversion"
        return
    end if

    m.conversionStatus.visible = false
    sentryCaptureEvent(createConversionFailureEvent(obj.getData(), m.method, m.file))
    showPlaybackUnavailableDialog("conversion_failed")
end sub

sub onVideoConversionCompleted()
    if m.phase <> "conversion"
        return
    end if

    m.conversionStatus.visible = false
    m.file = m.conversionStatus.completedFile
    m.conversionCompleted = true
    setTitle(m.file.name)
    showLoading()
    resolvePlayback(m.method = "file", m.plan.reason)
end sub

sub showContinueWatchingPrompt()
    m.phase = "resumePrompt"
    m.continueWatchingPrompt.fileName = m.file.name
    m.continueWatchingPrompt.duration = getVideoFileDurationSeconds(m.file)
    m.continueWatchingPrompt.startFrom = m.fetchedStartFrom
    m.continueWatchingPrompt.visible = true
    m.continueWatchingPrompt.setFocus(true)
end sub

sub onContinueWatchingPromptSelected(obj)
    if m.phase <> "resumePrompt"
        return
    end if

    m.continueWatchingPrompt.visible = false
    navigateToVideoPlayer(obj.getData())
end sub

sub onContinueWatchingPromptDismissed()
    if m.phase = "resumePrompt"
        m.continueWatchingPrompt.visible = false
        m.top.navigateBack = true
    end if
end sub

sub navigateToVideoPlayer(startFrom)
    m.phase = "launchingPlayer"
    m.top.navigate = {
        id: "videoPlayerScreen",
        replace: true,
        params: {
            file: m.file,
            subtitles: m.subtitles,
            plan: m.plan,
            method: m.method,
            startFrom: startFrom
        }
    }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top, [m.continueWatchingPrompt, m.conversionStatus])
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            m.top.navigateBack = true
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function

function shouldResumeFrom(startFrom as integer) as boolean
    if startFrom <= 0
        return false
    end if

    return not isPlaybackFinishedAt(startFrom, getVideoFileDurationSeconds(m.file))
end function
